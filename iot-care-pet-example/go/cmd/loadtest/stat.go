package main

import (
	"log"
	"time"

	"github.com/codahale/hdrhistogram"
)

type S struct {
	Latency *hdrhistogram.Histogram

	lastPrintTS time.Time
	lastPrintTP int64
}

func New() *S {
	return &S{
		Latency: hdrhistogram.New(0, 1000, 2),
	}
}

func (s *S) Call(f func()) {
	start := time.Now()
	f()
	dt := time.Since(start)

	if err := s.Latency.RecordValue(int64(dt / time.Millisecond)); err != nil {
		log.Println("Invalid record value ", dt, ":", err)
	}
}

func (s *S) Print(prefix string) {
	t := time.Now()

	if t.Sub(s.lastPrintTS) < time.Second {
		return
	}

	total := s.Latency.TotalCount()
	cd := s.Latency.CumulativeDistribution()

	if len(cd) >= 15 {
		log.Printf(prefix+"total = %d, DT = %d, mean/stddev %0.2f/%0.2f %0.2f%%[%dms]/%0.2f%%[%dms]/%0.2f%%[%dms]",
			total, total-s.lastPrintTP,
			s.Latency.Mean(), s.Latency.StdDev(),
			cd[4].Quantile, cd[4].ValueAt,
			cd[6].Quantile, cd[6].ValueAt,
			cd[14].Quantile, cd[14].ValueAt,
		)
	} else {
		log.Printf(prefix+"total = %d, DT = %d, mean/stddev %0.2f/%0.2f",
			total, total-s.lastPrintTP, s.Latency.Mean(), s.Latency.StdDev())
	}

	s.lastPrintTS = t
	s.lastPrintTP = total
}
