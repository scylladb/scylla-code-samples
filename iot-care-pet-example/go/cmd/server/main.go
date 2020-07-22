package main

import (
	"log"

	"github.com/go-openapi/loads"
	"github.com/spf13/pflag"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/cmd/server/restapi"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/cmd/server/restapi/operations"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/config"
)

var verbose = pflag.Bool("verbose", false, "output more info")

func main() {
	pflag.Parse()

	if *verbose {
		log.Printf("Configuration = %+v\n", config.Config())
	}

	api := operations.NewCarePetAPI(spec())
	server := restapi.NewServer(api)
	defer server.Shutdown()

	configure(server)
	server.ConfigureAPI()

	if err := server.Serve(); err != nil {
		log.Fatalln(err)
	}
}

func spec() *loads.Document {
	swaggerSpec, err := loads.Embedded(restapi.SwaggerJSON, restapi.FlatSwaggerJSON)
	if err != nil {
		log.Fatalln(err)
	}
	return swaggerSpec
}
