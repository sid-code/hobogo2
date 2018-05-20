package spapi

import (
	"encoding/json"
	"flights/util"
	"fmt"
	"net/http"
	"strings"
	"time"
)

type TimeRange struct {
	Start time.Time
	End   time.Time
}

// A SearchParams object is fed into this API abstraction
type SearchParams struct {
	TimeWindow TimeRange
	StartLoc   string
	DestList   []string
	Passengers int64
}

// A Flight object (slice) is what is returned from this API abstraction
type Flight struct {
	ID         int64     `db:"id"          json:"id"`
	Loc        string    `db:"loc"         json:"loc"`
	From       string    `db:"frm"         json:"from"`
	DepartTime time.Time `db:"departtime"  json:"departtime"`
	ArriveTime time.Time `db:"arrivetime"  json:"arrivetime"`
	Price      float64   `db:"price"       json:"price"`
	DeepLink   string    `db:"deeplink"    json:"deeplink"`
	Passengers int64     `db:"passengers"  json:"passengers"`
}

func (fl *Flight) String() string {
	return fmt.Sprintf("%s -> %s [%g]", fl.From, fl.Loc, fl.Price)
}

func (fl *Flight) FieldTable() map[string]interface{} {
	return map[string]interface{}{
		"id":         fl.ID,
		"loc":        fl.Loc,
		"frm":        fl.From,
		"departTime": fl.DepartTime,
		"arriveTime": fl.ArriveTime,
		"price":      fl.Price,
		"deepLink":   fl.DeepLink,
		"passengers": fl.Passengers,
	}
}

// This is all because sqlx doesn't support variadic named execution
func (fl *Flight) addToAccumulator(acc []interface{}) []interface{} {
	acc = append(acc, fl.ID)
	acc = append(acc, fl.Loc)
	acc = append(acc, fl.From)
	acc = append(acc, fl.DepartTime)
	acc = append(acc, fl.ArriveTime)
	acc = append(acc, fl.Price)
	acc = append(acc, fl.DeepLink)
	acc = append(acc, fl.Passengers)
	return acc
}

const endpointBaseURL = "https://api.skypicker.com"
const flightsPath = "/flights"

func MakeDateString(t time.Time) string {
	return t.Format("2/1/2006")
}

const badValErrStr = "skypicker API result has invalid %s value: %s"

func ExtractFlight(data map[string]interface{}) (*Flight, error) {
	result := &Flight{}
	var ok bool
	var departTimeRaw, arriveTimeRaw float64

	id, err := util.RandID()
	if err != nil {
		return nil, fmt.Errorf("failed to make an ID: %v", err)
	}

	result.ID = id

	result.Loc, ok = data["flyTo"].(string)
	if !ok {
		return nil, fmt.Errorf(badValErrStr, "flyTo", data["flyTo"])
	}

	result.From, ok = data["flyFrom"].(string)
	if !ok {
		return nil, fmt.Errorf(badValErrStr, "flyFrom", data["flyFrom"])
	}

	departTimeRaw, ok = data["dTime"].(float64)
	if !ok {
		return nil, fmt.Errorf(badValErrStr, "dTime", data["dTime"])
	}

	result.DepartTime = time.Unix(int64(departTimeRaw), 0)

	arriveTimeRaw, ok = data["aTime"].(float64)
	if !ok {
		return nil, fmt.Errorf(badValErrStr, "aTime", data["aTime"])
	}

	result.ArriveTime = time.Unix(int64(arriveTimeRaw), 0)

	result.Price, ok = data["price"].(float64)
	if !ok {
		return nil, fmt.Errorf(badValErrStr, "price", data["price"])
	}

	result.DeepLink, ok = data["deep_link"].(string)
	if !ok {
		return nil, fmt.Errorf(badValErrStr, "deep_link", data["deep_link"])
	}

	return result, nil
}

func SearchFlightsRaw(c *http.Client, params SearchParams) ([]*Flight, error) {
	req, err := http.NewRequest("GET", endpointBaseURL+flightsPath, nil)
	if err != nil {
		return nil, err
	}

	q := req.URL.Query()
	q.Add("flyFrom", params.StartLoc)
	q.Add("dateFrom", MakeDateString(params.TimeWindow.Start))
	q.Add("dateTo", MakeDateString(params.TimeWindow.End))
	q.Add("to", strings.Join(params.DestList, ","))

	q.Add("partner", "picky")
	q.Add("curr", "USD")
	q.Add("sort", "price")
	req.URL.RawQuery = q.Encode()

	resp, err := c.Do(req)
	if err != nil {
		return nil, err
	}

	defer resp.Body.Close()
	dec := json.NewDecoder(resp.Body)

	var m map[string]interface{}

	if err := dec.Decode(&m); err != nil {
		return nil, err
	}

	var results []*Flight
	for k, v := range m {
		switch vt := v.(type) {
		case []interface{}:
			if k == "data" {
				for _, flight := range vt {
					result, err := ExtractFlight(flight.(map[string]interface{}))
					result.Passengers = params.Passengers
					if err != nil {
						return nil, err
					}

					good := false
					for _, dest := range params.DestList {
						if result.Loc == dest {
							good = true
							break
						}
					}

					if !good {
						return nil, fmt.Errorf("Invalid destination returned by api: %s (valid: %s)", result.Loc, strings.Join(params.DestList, ","))
					}
					results = append(results, result)
				}
			}
		}
	}

	return results, nil
}
