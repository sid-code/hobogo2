package main

import (
	"flights/fconfig"
	"flights/manager"
	"flights/server"
	"flights/spapi"
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	confPath := os.Getenv("FSERVER_CONF")
	log.Printf("Reading configuration %s\n", confPath)

	conf := fconfig.ReadConfiguration(confPath)

	hcl := &http.Client{
		Timeout: 20 * time.Minute,
	}

	c, err := manager.MakeCache(conf)
	if err != nil {
		log.Fatal(err)
	}

	cl := spapi.NewClient(hcl, c)

	server, err := server.NewServer(conf, cl)
	if err != nil {
		log.Fatal(err)
	}
	server.Serve()
}
