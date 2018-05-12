package fconfig

import (
	"github.com/BurntSushi/toml"
	"io/ioutil"
	"log"
	"time"
)

type Server struct {
	Host string
	Port int64
}

type Postgres struct {
	Server
	User     string
	Password string
	Database string
	SSLmode  string
}

type Config struct {
	Postgres  Postgres
	WebServer Server
	FBinSize  time.Duration
}

type duration struct {
	time.Duration
}

func (d *duration) UnmarshalText(text []byte) error {
	var err error
	d.Duration, err = time.ParseDuration(string(text))
	return err
}

func ReadConfiguration(path string) Config {
	cfg := Config{}
	configText, err := ioutil.ReadFile(path)

	if err != nil {
		log.Fatalf("failed to read configuration file (%s): %v", path, err)
	}

	if _, err = toml.Decode(string(configText), &cfg); err != nil {
		log.Fatalf("configuration error (%s): %v", path, err)
	}

	return cfg
}
