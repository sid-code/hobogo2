package server

import ()

type Message struct {
	Kind    string `json:"kind"`
	Payload string `json:"payload"`
}
