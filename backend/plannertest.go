package main

import (
	"flights/fconfig"
	"flights/manager"
	"flights/planner"
	"flights/spapi"
	"fmt"
	"log"
	"net/http"
	"time"
)

func main() {
	gconf := fconfig.ReadConfiguration("./conf.toml")

	days := time.Hour * 24
	wind := spapi.TimeRange{
		Start: time.Now(),
		End:   time.Now().Add(30 * days),
	}

	conf := planner.Config{
		HomeLoc:          "LAX",
		TimeWindow:       wind,
		DestList:         []string{"LGW", "PRG", "AMS", "DUB", "LPL", "BUD"},
		MaxStay:          days * 5,
		MinStay:          days * 2,
		FlightDiff:       time.Hour * 4,
		MaxPrice:         1200,
		MinLength:        4,
		ConcurrentSearch: 1,
		Passengers:       2,
	}

	hcl := &http.Client{
		Timeout: 20 * time.Minute,
	}

	c, err := manager.MakeCache(gconf)
	if err != nil {
		log.Fatal(err)
	}

	cl := spapi.NewClient(hcl, c)

	pl := planner.NewPlanner(conf, cl)

	resc, errc, finc := pl.Channels()
	go pl.Search()

	for {
		select {
		case result := <-resc:
			fmt.Println("Result", result)
		case <-finc:
			fmt.Println("wew done")
			return
		case err := <-errc:
			log.Fatal(err)
		}
	}

}
