package manager

import (
	"flights/fconfig"
	"flights/spapi"
	"golang.org/x/net/context"
	"time"
)

func MakeCache(config fconfig.Config) (*spapi.Cache, error) {
	ctx, _ := context.WithTimeout(context.Background(), 20*time.Hour)

	return spapi.NewCache(ctx, config.SpannerDatabase, config.FBinSize)
}
