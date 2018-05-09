package manager

import (
	"flights/fconfig"
	"flights/spapi"
	"fmt"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq" // postgres driver
	"golang.org/x/net/context"
	"log"
	"time"
)

func MakeCache(config fconfig.Config) (*spapi.Cache, error) {
	ctx, _ := context.WithTimeout(context.Background(), 20*time.Hour)

	connStr := fmt.Sprintf("user=%s password=%s host=%s port=%d dbname=%s sslmode=%s",
		config.Postgres.User,
		config.Postgres.Password,
		config.Postgres.Host,
		config.Postgres.Port,
		config.Postgres.Database,
		config.Postgres.SSLmode)

	log.Printf("Connecting to postgres with: %s\n", connStr)

	db, err := sqlx.Connect("postgres", connStr)

	if err != nil {
		return nil, err
	}

	return spapi.NewCache(ctx, db, config.FBinSize)
}
