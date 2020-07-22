package main

import (
	"context"
	"log"
	"time"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/db"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/model"
	"github.com/scylladb/gocqlx/v2"
)

type pet struct {
	id model.UUID
	s  gocqlx.Session
	f  *flock
}

func NewPet(id model.UUID, s gocqlx.Session, f *flock) *pet {
	return &pet{
		id: id,
		s:  s,
		f:  f,
	}
}

func (p *pet) run(ctx context.Context) {
	var m = &model.Measure{}
	var sensors = p.f.Sensors[p.id]

	var q = db.TableMeasure.InsertQueryContext(ctx, p.s)
	defer q.Release()

	if *verbose {
		log.Println("pet #", p.id, "ready")
	}

	for {
		for _, sen := range sensors {
			m.SensorID = sen.SensorID
			m.TS = time.Now()
			m.Value = model.RandSensorData(sen)

			if err := q.BindStruct(m).Exec(); err != nil {
				log.Println("pet #", p.id, "error:", err)
			}
		}

		time.Sleep(*interval)
	}
}
