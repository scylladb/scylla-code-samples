package model

import (
	"time"
)

type SensorAvg struct {
	SensorID UUID
	Date     time.Time
	Hour     int
	Value    float32
}
