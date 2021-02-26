package model

import (
	"time"
)

type Measure struct {
	SensorID UUID
	TS       time.Time
	Value    float32
}
