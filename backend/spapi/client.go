package spapi

import (
	"net/http"
)

type Client struct {
	hcl  *http.Client
	c    *Cache
	resc chan *Flight // flight channel
	errc chan error   // error channel
	finc chan bool    // are we done yet?
}

func (r *Client) Channels() (chan *Flight, chan error, chan bool) {
	return r.resc, r.errc, r.finc
}

func NewClient(hcl *http.Client, c *Cache) *Client {
	cl := &Client{
		hcl:  hcl,
		c:    c,
		resc: make(chan *Flight),
		errc: make(chan error),
		finc: make(chan bool),
	}

	return cl
}

func (cl *Client) SearchFlights(params SearchParams) {
	go cl.c.searchFlights(cl.hcl, params, cl.resc, cl.errc, cl.finc)
}
