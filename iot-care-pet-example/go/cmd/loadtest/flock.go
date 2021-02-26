package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"sync"

	"github.com/scylladb/gocqlx/v2"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/config"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/db"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/model"
)

type flock struct {
	wg sync.WaitGroup

	Owners  map[model.UUID]*model.Owner
	Pets    map[model.UUID]*model.Pet
	Sensors map[model.UUID][]*model.Sensor
}

// newFlock generates a random flock.
// Sensors depicts maximum number of sensors per pet.
func newFlock(owners int, pets int, sensors int) *flock {
	f := &flock{
		Owners:  map[model.UUID]*model.Owner{},
		Pets:    map[model.UUID]*model.Pet{},
		Sensors: map[model.UUID][]*model.Sensor{},
	}

	ows := make([]*model.Owner, 0, owners)

	for i := 0; i < owners; i++ {
		o := model.RandOwner()
		f.Owners[o.OwnerID] = o
		ows = append(ows, o)
	}

	log.Println("Owners created")

	for i := 0; i < pets; i++ {
		p := model.RandPet(ows[rand.Intn(owners)])
		f.Pets[p.PetID] = p

		t := 1 + rand.Intn(sensors)
		for i := 0; i < t; i++ {
			s := model.RandSensor(p)
			f.Sensors[s.PetID] = append(f.Sensors[s.PetID], s)
		}
	}

	log.Println("Pets created")

	return f
}

func (f *flock) Save(ctx context.Context) *flock {
	s, err := config.Keyspace()
	if err != nil {
		log.Fatalln("session:", err)
	}

	defer s.Close()

	if err = save(ctx, s, f); err != nil {
		log.Fatalln("save flock:", err)
	}

	return f
}

func (f *flock) Go(t func()) {
	f.wg.Add(1)
	go t()
}

func (f *flock) Done() {
	f.wg.Done()
}

func (f *flock) Wait(ctx context.Context) {
	finish := make(chan struct{})

	go func() {
		f.wg.Wait()
		close(finish)
	}()

	select {
	case <-ctx.Done():
	case <-finish:
	}
}

func save(ctx context.Context, ses gocqlx.Session, f *flock) error {
	for _, o := range f.Owners {
		if err := db.TableOwner.InsertQueryContext(ctx, ses).BindStruct(o).ExecRelease(); err != nil {
			return fmt.Errorf("insert owner %s: %w", o.OwnerID.String(), err)
		}
	}

	for _, p := range f.Pets {
		if err := db.TablePet.InsertQueryContext(ctx, ses).BindStruct(p).ExecRelease(); err != nil {
			return fmt.Errorf("insert pet %s: %w", p.PetID.String(), err)
		}
	}

	for _, petSensors := range f.Sensors {
		for _, s := range petSensors {
			if err := db.TableSensor.InsertQueryContext(ctx, ses).BindStruct(s).ExecRelease(); err != nil {
				return fmt.Errorf("insert sensor %s: %w", s.SensorID.String(), err)
			}
		}
	}

	return nil
}

func startPets(ctx context.Context, f *flock, ses gocqlx.Session) {
	for id := range f.Pets {
		f.Go(func() {
			defer ses.Close()
			NewPet(id, ses, f).run(ctx)
		})
	}
}
