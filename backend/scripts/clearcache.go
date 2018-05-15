package main

import (
	"flights/fconfig"
	"flights/manager"
	"log"
)

func main() {
	configPath := "./conf.toml"
	conf, err := fconfig.ReadConfiguration(configPath)
	if err != nil {
		log.Fatal(err)
	}

	cache, err := manager.MakeCache(conf)
	if err != nil {
		log.Fatal(err)
	}

	err = cache.Clear()
	if err != nil {
		log.Fatal(err)
	}
}
