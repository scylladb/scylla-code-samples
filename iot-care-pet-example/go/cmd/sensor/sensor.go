package main

import (
	"context"
	"log"

	"github.com/spf13/pflag"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/config"
)

var verbose = pflag.Bool("verbose", false, "output more info")

func main() {
	pflag.Parse()

	log.Println("Welcome to the Pet collar simulator")

	if *verbose {
		log.Printf("Configuration = %+v\n", config.Config())
	}

	ses, err := config.Keyspace()
	if err != nil {
		log.Fatalln("session: ", err)
	}
	defer ses.Close()

	pet := NewPet()

	if err := pet.save(context.Background(), ses); err != nil {
		log.Fatalln("pet save: ", err)
	}

	log.Println("New owner #", pet.p.OwnerID)
	log.Println("New pet #", pet.p.PetID)

	pet.run(context.Background(), ses)
}
