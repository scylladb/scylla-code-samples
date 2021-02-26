package main

import (
	"context"
	"log"
	"strconv"
	"time"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/db"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/model"
	"github.com/scylladb/gocqlx/v2"
)

func worker(ctx context.Context, f *flock, id int, ses gocqlx.Session) {
	if *verbose {
		log.Println("writer #", id, "ready")
	}

	var m = &model.Measure{}
	var prefix = "#" + strconv.Itoa(id) + " "
	var s = New()
	var q = db.TableMeasure.InsertQueryContext(ctx, ses)
	defer q.Release()

	for {
		for _, sensors := range f.Sensors {
			for _, sen := range sensors {
				m.SensorID = sen.SensorID
				m.TS = time.Now()
				m.Value = model.RandSensorData(sen)

				s.Call(func() {
					if err := q.BindStruct(m).Exec(); err != nil {
						log.Println("writer #", id, "error:", err)
					}
				})
			}

			s.Print(prefix)
		}
	}
}
