package fconfig

import (
	"github.com/pelletier/go-toml"
	"log"
	"time"
)

type Config struct {
	SpannerDatabase string
	FBinSize        time.Duration
}

func ReadConfiguration(path string) Config {
	cfg := Config{}
	tt, err := toml.LoadFile(path)

	if err != nil {
		log.Fatalf("configuration error: %v", err)
	}

	tt.Unmarshal(&cfg)

	return cfg
}
