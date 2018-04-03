package spapi

import (
	"cloud.google.com/go/spanner"
	_ "cloud.google.com/go/spanner/admin/database/apiv1" /* database */
	"flights/util"
	"fmt"
	"golang.org/x/net/context"
	"google.golang.org/api/iterator"
	_ "google.golang.org/genproto/googleapis/spanner/admin/database/v1" /* adminpb */
	"net/http"
	"strings"
	"time"
)

type Cache struct {
	ctx      context.Context
	client   *spanner.Client
	fbinsize time.Duration
}

func NewCache(ctx context.Context, db string, fbinsize time.Duration) (*Cache, error) {
	cl, err := spanner.NewClient(ctx, db)
	if err != nil {
		return nil, fmt.Errorf("unable to create spanner client: %v", err)
	}
	c := &Cache{ctx: ctx, client: cl, fbinsize: fbinsize}
	err = c.init()
	if err != nil {
		return nil, err
	}
	return c, nil
}

func (c *Cache) init() error {
	return nil
}

func (c *Cache) Clear() error {
	mut := spanner.Delete("flcache", spanner.KeyRange{
		Start: spanner.Key{-9223372036854775808},
		End:   spanner.Key{9223372036854775807},
		Kind:  spanner.ClosedClosed,
	})

	_, err := c.client.Apply(c.ctx, []*spanner.Mutation{mut})

	return err
}

func (c *Cache) search(params SearchParams) ([]*Flight, error) {
	locList := "'" + strings.Join(params.DestList, "','") + "'"

	sql := fmt.Sprintf(`SELECT * FROM flcache WHERE loc IN ( %s ) AND frm = @frm AND passengers = @passengers AND departTime > @earliest AND departTime < @latest ORDER BY price ASC`, locList)
	table := map[string]interface{}{
		"frm":        params.StartLoc,
		"earliest":   util.FormatSpannerTimestamp(params.TimeWindow.Start),
		"latest":     util.FormatSpannerTimestamp(params.TimeWindow.End),
		"passengers": params.Passengers,
	}
	stmt := spanner.Statement{
		SQL:    sql,
		Params: table,
	}

	op := c.client.Single()
	iter := op.Query(c.ctx, stmt)

	defer iter.Stop()

	var result []*Flight

	for {
		fl := &Flight{}
		row, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("error while reading rows from response: %v", err)
		}

		err = row.ToStruct(fl)
		if err != nil {
			return nil, fmt.Errorf("failed to scan flight from db row: %v", err)
		}
		result = append(result, fl)
	}

	return result, nil
}

func makeMutation(fl *Flight) *spanner.Mutation {
	keys := []string{"id", "frm", "loc", "departTime", "arriveTime", "deepLink", "price", "passengers"}
	vals := []interface{}{
		fl.Id,
		fl.From,
		fl.Loc,
		util.FormatSpannerTimestamp(fl.DepartTime),
		util.FormatSpannerTimestamp(fl.ArriveTime),
		fl.DeepLink,
		fl.Price,
		fl.Passengers,
	}
	mut := spanner.Insert("flcache", keys, vals)

	return mut
}

func (c *Cache) searchFlights(cl *http.Client, params SearchParams, resc chan *Flight, errc chan error, finc chan bool) {
	cached, err := c.search(params)
	if err != nil {
		errc <- err
		return
	}

	fmt.Printf("Got %d from cache\n", len(cached))

	for _, fl := range cached {
		resc <- fl
	}

	res, err := SearchFlightsRaw(cl, params)
	if err != nil {
		errc <- err
		return
	}

	var muts []*spanner.Mutation

	for _, fl := range res {
		resc <- fl
		muts = append(muts, makeMutation(fl))
		if len(muts) > 100 {
			_, err = c.client.Apply(c.ctx, muts)
			if err != nil {
				errc <- err
			}
			muts = nil
		}

	}

	finc <- true
}
