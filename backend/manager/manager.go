package manager

import (
	"flights/fconfig"
	"flights/spapi"
	"fmt"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq" // postgres driver
	"log"
	"os"
)

func MakeCache(config fconfig.Config) (*spapi.Cache, error) {
	var connStr string

	connFromEnv := os.Getenv("POSTGRES_CONNECTION")
	if connFromEnv == "" {
		connStr = fmt.Sprintf(
			"user=%s password=%s host=%s port=%d dbname=%s sslmode=%s",
			config.Postgres.User,
			config.Postgres.Password,
			config.Postgres.Host,
			config.Postgres.Port,
			config.Postgres.Database,
			config.Postgres.SSLmode)
	} else {
		connStr = connFromEnv
	}

	log.Printf("Connecting to postgres with: %s\n", connStr)

	db, err := sqlx.Connect("postgres", connStr)

	if err != nil {
		return nil, err
	}

	return spapi.NewCache(db, config.FBinSize)
}
