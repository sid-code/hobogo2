package spapi

import (
	"fmt"
	"github.com/jmoiron/sqlx"
	_ "github.com/lib/pq" // postgres driver
	"net/http"
	"strings"
	"time"
)

const schemaSQL = `
CREATE TABLE IF NOT EXISTS flcache (
	id            BIGINT NOT NULL PRIMARY KEY,
	loc           TEXT NOT NULL,
	frm           TEXT NOT NULL,
	departTime    DATE NOT NULL,
	arriveTime    DATE NOT NULL,
	price         REAL NOT NULL,
	deepLink      TEXT NOT NULL,
	passengers    INTEGER NOT NULL,
        UNIQUE(id)
)
`

const searchSQL = `
SELECT * FROM flcache
WHERE loc IN ( %s )
  AND frm = :frm
  AND passengers = :passengers
  AND departTime > :earliest
  AND departTime < :latest
ORDER BY price ASC
LIMIT 40
`

const findDuplicateSQL = `
SELECT * FROM flcache
WHERE loc = :loc
  AND frm = :frm
  AND departTime = :departTime
  AND arriveTime = :arriveTime
  AND price = :price
  AND passengers = :passengers
`

const removeSimilarSQL = `
DELETE FROM flcache
WHERE loc = :loc
  AND frm = :frm
  AND abs(departTime - :departTime) < :fbinsize
  AND price > :price
  AND passengers = :passengers
`

const insertSQL = `
INSERT INTO flcache(id, loc, frm, departTime, arriveTime, price, deepLink, passengers)
VALUES ( :id, :loc, :frm, :departTime, :arriveTime, :price, :deepLink, :passengers )
`

const deleteSQL = `
DELETE FROM flcache WHERE id=:id
`

type Cache struct {
	db       *sqlx.DB
	fbinsize time.Duration
}

func NewCache(db *sqlx.DB, fbinsize time.Duration) (*Cache, error) {
	c := &Cache{db: db, fbinsize: fbinsize}
	err := c.init()
	if err != nil {
		return nil, err
	}
	return c, nil
}

func (c *Cache) init() error {
	_, err := c.db.Exec(schemaSQL)
	return err
}

func (c *Cache) Clear() error {
	return nil
}

func (c *Cache) Search(params SearchParams) ([]*Flight, error) {
	locList := "'" + strings.Join(params.DestList, "','") + "'"

	sql := fmt.Sprintf(searchSQL, locList)
	table := map[string]interface{}{
		"frm":        params.StartLoc,
		"earliest":   params.TimeWindow.Start,
		"latest":     params.TimeWindow.End,
		"passengers": params.Passengers,
	}
	rows, err := c.db.NamedQuery(sql, table)

	if err != nil {
		return nil, fmt.Errorf("Failed to search flights: %v", err)
	}

	var result []*Flight

	for rows.Next() {
		fl := &Flight{}

		err = rows.StructScan(fl)
		if err != nil {
			return nil, fmt.Errorf("failed to scan flight from db row: %v", err)
		}
		result = append(result, fl)
	}

	return result, nil
}

func (c *Cache) Insert(fl *Flight) error {
	table := fl.FieldTable()
	_, err := c.db.NamedExec(insertSQL, table)
	if err != nil {
		return fmt.Errorf("failed to insert flight: %v", err)
	}

	return nil
}

func (c *Cache) Delete(fl *Flight) error {
	_, err := c.db.NamedExec(deleteSQL, map[string]interface{}{"id": fl.ID})
	if err != nil {
		return fmt.Errorf("failed to delete flight: %v", err)
	}

	return nil
}

func (c *Cache) searchFlights(cl *http.Client, params SearchParams, resc chan *Flight, errc chan error, finc chan bool) {
	cached, err := c.Search(params)
	if err != nil {
		errc <- err
		return
	}

	fmt.Printf("Got %d from cache: %s\n", len(cached), params)

	for _, fl := range cached {
		resc <- fl
	}

	res, err := SearchFlightsRaw(cl, params)
	if err != nil {
		errc <- err
		return
	}

	fmt.Printf("But got %d from search\n", len(res))

	for _, fl := range res {
		resc <- fl
		err := c.Insert(fl)
		if err != nil {
			errc <- err
			break
		}
	}

	finc <- true
}
