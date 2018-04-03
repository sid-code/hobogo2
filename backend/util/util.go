package util

import (
	"crypto/rand"
	"encoding/binary"
	"time"
)

func FormatSpannerTimestamp(t time.Time) string {
	return t.Format("2006-01-02T15:04:05.45Z")
}

func RandID() (int64, error) {
	var b [8]byte
	if _, err := rand.Read(b[:]); err != nil {
		return 0, err
	}
	return int64(binary.LittleEndian.Uint64(b[:])), nil
}
