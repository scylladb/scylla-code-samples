package main

import (
	"context"
	"log"
	"runtime"
	"time"

	"github.com/spf13/pflag"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/config"
)

var owners = pflag.Int("owners", 100, "number of the startPets owners")
var pets = pflag.Int("pets", 100, "number of startPets to simulate")
var sensors = pflag.Int("sensors", 4, "number of sensors per pet")
var interval = pflag.Duration("measurement-interval", time.Second, "an interval between sensors measurements")
var verbose = pflag.Bool("verbose", false, "output more info")

var writer = pflag.Bool("writer", false, "just write random data")
var workers = pflag.Int("p", runtime.NumCPU(), "number of parallel writers")

func main() {
	var ctx = context.Background()

	pflag.Parse()

	SetNoFile(102400)

	log.Println("Welcome to the Pets simulator")
	if *verbose {
		log.Printf("Configuration = %+v\n", config.Config())
	}

	log.Println("Creating flock")
	f := newFlock(*owners, *pets, *sensors).Save(ctx)
	log.Println("Flock created")

	ses, err := config.Keyspace()
	if err != nil {
		log.Fatal("keyspace: ", err)
	}
	defer ses.Close()

	if *writer {
		for i := 0; i < *workers; i++ {
			f.Go(func() { worker(ctx, f, i+1, ses) })
		}
		log.Println("Writers started")
	} else {
		startPets(ctx, f, ses)
		log.Println("Flock started")
	}

	f.Wait(ctx)

	log.Println("Finished")
}
