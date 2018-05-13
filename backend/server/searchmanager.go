package server

import (
	"encoding/json"
	"flights/planner"
	"flights/spapi"
	"fmt"
	"github.com/gorilla/websocket"
	"github.com/satori/go.uuid"
	"log"
	"net/http"
)

type Search struct {
	ID          uuid.UUID
	planner     *planner.Planner
	subscribers []*websocket.Conn
	backlog     [][]*spapi.Flight
	mgr         *SearchManager
}

type SearchManager struct {
	searches map[uuid.UUID]*Search
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 4096,
}

func newSearch(config planner.Config, cl *spapi.Client) (*Search, error) {
	token, err := uuid.NewV4()
	if err != nil {
		return nil, fmt.Errorf("failed to generate uuid: %v", err)
	}

	plnr := planner.NewPlanner(config, cl)
	return &Search{
		ID:          token,
		planner:     plnr,
		subscribers: nil,
		backlog:     nil,
	}, nil
}

func (s *Search) addResult(res *planner.Node) {
	fls := res.BuildChain()
	s.backlog = append(s.backlog, fls)
	for _, c := range s.subscribers {
		sendResult(c, fls)
	}
}

func sendResult(conn *websocket.Conn, result []*spapi.Flight) {
	buf, err := json.Marshal(result)
	if err != nil {
		// TODO: better error handling
		log.Fatalf("failed to jsonify flight data: %v", err)
	}
	conn.WriteMessage(websocket.TextMessage, buf)
}

func (s *Search) newClient(conn *websocket.Conn) {
	for _, b := range s.backlog {
		sendResult(conn, b)
	}
}

func (s *Search) finish() {
	for _, conn := range s.subscribers {
		err := conn.WriteMessage(websocket.CloseMessage, []byte{})
		if err != nil {
			// TODO: better error handling
			log.Fatal(err)
		}
	}
	delete(s.mgr.searches, s.ID)
}

func (s *Search) Search() {
	go s.planner.Search()
	resc, errc, finc := s.planner.Channels()
	for {
		select {
		case res := <-resc:
			s.addResult(res)
		case err := <-errc:
			s.finish()
			log.Fatal(err) // TODO: better error handling
		case <-finc:
			fmt.Printf("FINISHED\n")
			s.finish()
		}
	}

}

func (sm *SearchManager) NewSearch(config planner.Config, cl *spapi.Client) (*Search, error) {
	s, err := newSearch(config, cl)
	if err != nil {
		return nil, fmt.Errorf("failed to create search manager: %v", err)
	}

	s.mgr = sm
	sm.searches[s.ID] = s

	return s, nil
}

func (sm *SearchManager) FindSearch(id uuid.UUID) *Search {
	return sm.searches[id]
}

func (s *Search) UpgradeToWS(w http.ResponseWriter, r *http.Request) error {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return err
	}

	s.subscribers = append(s.subscribers, conn)
	s.newClient(conn)

	return nil
}
