package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"time"

	"github.com/scylladb/gocqlx/v2"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/db"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/model"
)

type pet struct {
	o *model.Owner
	p *model.Pet
	s []*model.Sensor
}

func NewPet() *pet {
	o := model.RandOwner()

	p := &pet{
		o: o,
		p: model.RandPet(o),
	}

	t := 1 + rand.Intn(len(model.SensorTypes))
	for i := 0; i < t; i++ {
		p.s = append(p.s, model.RandSensor(p.p))
	}

	return p
}

func (p *pet) save(ctx context.Context, s gocqlx.Session) error {
	if err := db.TableOwner.InsertQueryContext(ctx, s).BindStruct(p.o).ExecRelease(); err != nil {
		return fmt.Errorf("insert owner %s: %w", p.o.OwnerID.String(), err)
	}

	if err := db.TablePet.InsertQueryContext(ctx, s).BindStruct(p.p).ExecRelease(); err != nil {
		return fmt.Errorf("insert pet %s: %w", p.p.PetID.String(), err)
	}

	for _, sen := range p.s {
		if err := db.TableSensor.InsertQueryContext(ctx, s).BindStruct(sen).ExecRelease(); err != nil {
			return fmt.Errorf("insert sensor %s: %w", sen.SensorID.String(), err)
		}
	}

	return nil
}

func (p *pet) run(ctx context.Context, s gocqlx.Session) {
	var m = &model.Measure{}

	if *verbose {
		log.Println("pet #", p.p.PetID, "ready")
	}

	for {
		for _, sen := range p.s {
			readSensorData(sen, m)

			if err := db.TableMeasure.InsertQueryContext(ctx, s).BindStruct(m).ExecRelease(); err != nil {
				log.Println("sensor #", sen.SensorID, "error:", err)
				continue
			}

			log.Println("sensor #", sen.SensorID, "type", sen.Type, "new measure", m.Value, "ts", m.TS.Format(time.RFC3339))
		}

		time.Sleep(time.Second)
	}
}

func readSensorData(sen *model.Sensor, m *model.Measure) {
	m.SensorID = sen.SensorID
	m.TS = time.Now()
	m.Value = model.RandSensorData(sen)
}
