package planner

import (
	"flights/spapi"
	"fmt"
	"time"
)

type Config struct {
	// Content options
	HomeLoc          string
	TimeWindow       spapi.TimeRange
	DestList         []string
	MaxStay, MinStay time.Duration
	FlightDiff       time.Duration
	MaxPrice         float64
	MinLength        int64
	Passengers       int64

	// Search options
	ConcurrentSearch int
}

type Node struct {
	fl          *spapi.Flight
	remaining   []string
	depth       int32
	CumPrice    float64
	Parent      *Node
	children    []*Node
	penultimate bool // Is this a penultimate node?
}

type Planner struct {
	config Config
	start  *Node
	cl     *spapi.Client
	resc   chan *Node
	errc   chan error
	finc   chan bool
}

func NewPlanner(config Config, cl *spapi.Client) *Planner {
	fakeFlight := &spapi.Flight{
		Loc:        config.HomeLoc,
		From:       "",
		DepartTime: time.Unix(0, 0),
		ArriveTime: config.TimeWindow.Start,
		Price:      0,
		DeepLink:   "",
		Passengers: 0,
	}
	start := &Node{
		fl:          fakeFlight,
		remaining:   config.DestList,
		depth:       0,
		CumPrice:    0,
		Parent:      nil,
		children:    nil,
		penultimate: false,
	}

	return &Planner{
		config: config,
		start:  start,
		cl:     cl,
		resc:   make(chan *Node),
		errc:   make(chan error),
		finc:   make(chan bool),
	}
}

func (pl *Planner) Channels() (chan *Node, chan error, chan bool) {
	return pl.resc, pl.errc, pl.finc
}

func (n *Node) makeChild(fl *spapi.Flight) *Node {
	var newRlocs []string
	found := false

	//newRlocs = make([]string, len(n.remaining)-1)

	for _, rl := range n.remaining {
		if rl != fl.Loc {
			newRlocs = append(newRlocs, rl)
		} else {
			found = true
		}
		//if rl == fl.Loc {
		//	copy(newRlocs, n.remaining[:i])
		//	copy(newRlocs[i:], n.remaining[i+1:])
		//	break
		//}
	}

	if !found {
		return nil
	}

	node := &Node{
		fl:          fl,
		remaining:   newRlocs,
		depth:       n.depth + 1,
		CumPrice:    n.CumPrice + fl.Price,
		Parent:      n,
		children:    nil,
		penultimate: n.penultimate,
	}

	return node
}

func minTime(t1, t2 time.Time) time.Time {
	if t1.After(t2) {
		return t2
	}

	return t1
}

func (n *Node) tryAddChild(c *Node, flightDiff time.Duration) int {
	for i, ec := range n.children {
		ecf := ec.fl
		cf := c.fl
		if ecf.Loc == cf.Loc && ecf.Price > cf.Price {
			timeDiff := c.fl.DepartTime.Sub(ec.fl.DepartTime)
			if timeDiff < flightDiff {
				n.children[i] = c
				return i
			}
		}
	}

	n.children = append(n.children, c)
	return len(n.children)
}

func (n *Node) String() string {
	return fmt.Sprintf("%s (depth=%d)", n.fl.String(), n.depth)
}

func (n *Node) BuildChain() []*spapi.Flight {
	var result []*spapi.Flight
	var nn *Node

	nn = n

	for {
		result = append([]*spapi.Flight{nn.fl}, result...)
		nn = nn.Parent
		if nn == nil {
			break
		}
	}

	return result
}

func (pl *Planner) searchNext(n *Node, childc chan *Node, errc chan error, finc chan bool) {
	config := pl.config
	dateFrom := n.fl.ArriveTime.Add(config.MinStay)
	dateTo := minTime(dateFrom.Add(config.MaxStay), config.TimeWindow.End)

	if dateFrom.After(dateTo) {
		//errc <- fmt.Errorf("%s is after %s", dateFrom, dateTo)
		finc <- true
		return
	}

	wind := spapi.TimeRange{Start: dateFrom, End: dateTo}
	params := spapi.SearchParams{
		TimeWindow: wind,
		StartLoc:   n.fl.Loc,
		DestList:   n.remaining,
		Passengers: config.Passengers,
	}

	pl.cl.SearchFlights(params)
	searchResc, searchErrc, searchFinc := pl.cl.Channels()

	for {
		select {
		case fl := <-searchResc:
			newNode := n.makeChild(fl)
			if newNode == nil {
				// lol idk why this happens
				//log.Printf("did I just get an invalid flight? %s %s\n", n.remaining, fl)
			} else {
				if newNode.CumPrice <= config.MaxPrice {
					n.tryAddChild(newNode, config.FlightDiff)
					childc <- newNode
				} else {
					//fmt.Printf("Pruned a fat price\n")
				}
			}
		case err := <-searchErrc:
			errc <- err
			return
		case <-searchFinc:
			finc <- true
			return
		}
	}
}

func addSorted(frontier []*Node, child *Node) []*Node {
	var i int
	var n *Node

	for i, n = range frontier {
		if n.depth < child.depth || n.CumPrice > child.CumPrice {
			break
		}
	}

	frontier = append(frontier, nil)
	copy(frontier[i+1:], frontier[i:])
	frontier[i] = child

	return frontier
}

// Goroutine
func (pl *Planner) Search() {
	var frontier []*Node
	frontier = append(frontier, pl.start)
	for len(frontier) > 0 {
		head := frontier[0]
		fmt.Printf("State of the art: %s  price=%g\n", head.BuildChain(), head.CumPrice)
		var heads []*Node
		nsearch := pl.config.ConcurrentSearch
		if nsearch >= len(frontier) {
			nsearch = len(frontier)
			heads = frontier
			frontier = nil
		} else {
			heads = frontier[:nsearch]
			frontier = frontier[nsearch+1:]
		}

		finished := make(chan int)
		fincount := 0

		addToFrontier := make(chan *Node)
		for i, h := range heads {
			go func(index int, head *Node) {
				childc := make(chan *Node)
				errc := make(chan error)
				finc := make(chan bool)
				go pl.searchNext(head, childc, errc, finc)

				for {
					select {
					case child := <-childc:
						if child.fl.Loc == pl.config.HomeLoc {
							pl.resc <- child
						} else {
							if int64(child.depth+1) >= pl.config.MinLength && !child.penultimate {
								child.remaining = append(child.remaining, pl.config.HomeLoc)
								child.penultimate = true
							}

							addToFrontier <- child
						}
					case err := <-errc:
						pl.errc <- err
						return
					case <-finc:
						finished <- index
						return
					}
				}
			}(i, h)

		}

		for {
			select {
			case child := <-addToFrontier:
				frontier = addSorted(frontier, child)
			case <-finished:
				fincount += 1
			}

			if fincount >= nsearch {
				break
			}
		}

	}

	pl.finc <- true
}
