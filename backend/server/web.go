package server

import (
	"encoding/json"
	"errors"
	"flights/fconfig"
	"flights/planner"
	"flights/spapi"
	"fmt"
	"github.com/satori/go.uuid"
	"log"
	"net/http"
	"time"
)

type FlightSearchServer struct {
	conf fconfig.Config
	cl   *spapi.Client
	srv  *http.Server
	mgr  *SearchManager
}

// This is what the JSON gets decoded into. It is then converted into
// a planner configuration
type searchRequest struct {
	HomeLoc    string   `json:"homeloc"`
	DestList   []string `json:"destlist"`
	StartTime  int64    `json:"starttime"`
	EndTime    int64    `json:"endtime"`
	MaxStay    int64    `json:"maxstay"`
	MinStay    int64    `json:"minstay"`
	MaxPrice   float64  `json:"maxprice"`
	MinLength  int64    `json:"minlength"`
	Passengers int64    `json:"passengers"`
}

func (s *FlightSearchServer) root(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusNotFound)
	fmt.Fprintf(w, "are you lost?")
}

func epochMStoTime(epochMS int64) (time.Time, error) {
	if epochMS < 0 {
		return time.Unix(0, 0), fmt.Errorf("time value %d cannot be negative", epochMS)
	}

	return time.Unix(epochMS/1000, 1000*(epochMS%1000)), nil
}

func searchRequestToPlannerConfig(sr searchRequest, gconf fconfig.Config) (planner.Config, error) {
	result := planner.Config{}

	if sr.HomeLoc == "" {
		return result, errors.New("home location required")
	}
	result.HomeLoc = sr.HomeLoc

	if len(sr.DestList) < 1 {
		return result, errors.New("destination list should be non-empty")
	}
	result.DestList = sr.DestList

	startTime, err := epochMStoTime(sr.StartTime)
	if err != nil {
		return result, err
	}
	if startTime.Before(time.Now()) {
		return result, errors.New("you can't start your trip in the past")
	}
	endTime, err := epochMStoTime(sr.EndTime)
	if err != nil {
		return result, err
	}
	if endTime.Before(time.Now()) {
		return result, errors.New("you can't end your trip in the past")
	}

	if endTime.Before(startTime) {
		return result, errors.New("you can't end your trip before you start it")
	}

	tw := spapi.TimeRange{Start: startTime, End: endTime}
	result.TimeWindow = tw

	if sr.MaxStay < 0 || sr.MinStay < 0 {
		return result, errors.New("please provide a positive number of days for max stay and min stay")
	}
	if sr.MinStay > sr.MaxStay {
		return result, errors.New("your maximum stay cannot be less than your minimum stay")
	}

	result.MaxStay = time.Duration(sr.MaxStay) * time.Hour * 24
	result.MinStay = time.Duration(sr.MinStay) * time.Hour * 24

	result.FlightDiff = gconf.FBinSize

	result.MaxPrice = sr.MaxPrice
	if sr.MinLength <= 0 {
		return result, errors.New("please provide a positive minimum length")
	}
	if sr.MinLength > int64(len(sr.DestList)+1) {
		return result, errors.New("you can't have a trip longer than your destination list")
	}
	result.MinLength = sr.MinLength

	if sr.Passengers <= 0 {
		sr.Passengers = 1
	}
	result.Passengers = sr.Passengers

	result.ConcurrentSearch = 1 // TODO: assign more intelligently

	return result, nil
}

func (s *FlightSearchServer) search(w http.ResponseWriter, r *http.Request) {
	var (
		sr    searchRequest
		pconf planner.Config
	)

	switch r.Method {
	case "POST":
		dec := json.NewDecoder(r.Body)
		defer r.Body.Close()

		err := dec.Decode(&sr)
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			fmt.Fprintf(w, "json decode error: %v", err)
			return
		}

		pconf, err = searchRequestToPlannerConfig(sr, s.conf)
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			fmt.Fprintf(w, "invalid input: %v", err)
			return
		}

		search, err := s.mgr.NewSearch(pconf, s.cl)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			fmt.Fprintf(w, "failed to initialize search: %v", err)
			return
		}

		go search.Search()
		w.WriteHeader(http.StatusOK)
		w.Header().Set("Content-Type", "application/json")

		result := struct {
			Token string `json:"token"`
		}{Token: search.ID.String()}
		json.NewEncoder(w).Encode(&result)
		break

	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}

}

func (s *FlightSearchServer) subscribe(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		token := r.URL.Query().Get("token")
		if token == "" {
			w.WriteHeader(http.StatusBadRequest)
			fmt.Fprintf(w, "must provide UUID token")
			return
		}

		id, err := uuid.FromString(token)
		if err != nil {
			w.WriteHeader(http.StatusBadRequest)
			fmt.Fprintf(w, "invalid token provided (must be canonical UUID)")
			return
		}

		search := s.mgr.FindSearch(id)
		if search == nil {
			w.WriteHeader(http.StatusNotFound)
			fmt.Fprintf(w, "search not found")
			return
		}

		err = search.UpgradeToWS(w, r)
		if err != nil {
			fmt.Fprintf(w, "failed to upgrade to websocket: %v", err)
			return
		}
	default:
		w.WriteHeader(http.StatusMethodNotAllowed)
	}

}

func NewServer(conf fconfig.Config, cl *spapi.Client) (*FlightSearchServer, error) {
	hdlr := http.NewServeMux()
	addr := fmt.Sprintf("%s:%d", conf.WebServer.Host, conf.WebServer.Port)
	srv := &http.Server{
		Addr:           addr,
		Handler:        hdlr,
		ReadTimeout:    10 * time.Second,
		WriteTimeout:   10 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}

	mgr := &SearchManager{
		searches: make(map[uuid.UUID]*Search),
	}

	result := &FlightSearchServer{
		conf: conf,
		cl:   cl,
		mgr:  mgr,
	}

	hdlr.Handle("/", http.HandlerFunc(result.root))
	hdlr.Handle("/search", http.HandlerFunc(result.search))
	hdlr.Handle("/subscribe", http.HandlerFunc(result.subscribe))

	result.srv = srv

	return result, nil
}

func (s *FlightSearchServer) Serve() {
	log.Printf("Starting server on %s", s.srv.Addr)
	log.Fatal(s.srv.ListenAndServe())
}
