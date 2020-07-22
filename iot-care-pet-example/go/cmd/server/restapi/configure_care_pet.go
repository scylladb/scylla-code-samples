// This file is safe to edit. Once it exists it will not be overwritten

package restapi

import (
	"crypto/tls"
	"log"
	"net/http"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/config"

	"github.com/go-openapi/errors"
	"github.com/go-openapi/runtime"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/cmd/server/restapi/operations"
	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/handler"
)

//go:generate swagger generate server --target .. --name CarePet --spec ../../../api/api.json --principal interface{}

func configureFlags(api *operations.CarePetAPI) {
	// api.CommandLineOptionsGroups = []swag.CommandLineOptionsGroup{ ... }
}

func configureAPI(api *operations.CarePetAPI) http.Handler {
	ses, err := config.Keyspace()
	if err != nil {
		log.Fatalln("keyspace: ", err)
	}

	// configure the api here
	api.ServeError = errors.ServeError

	// Set your custom logger if needed. Default one is log.Printf
	// Expected interface func(string, ...interface{})
	//
	// Example:
	// api.Logger = log.Printf

	api.UseSwaggerUI()
	// To continue using redoc as your UI, uncomment the following line
	// api.UseRedoc()

	api.JSONConsumer = runtime.JSONConsumer()

	api.JSONProducer = runtime.JSONProducer()

	api.FindOwnerByIDHandler = handler.FindOwnerByID(ses)
	api.FindPetsByOwnerIDHandler = handler.FindPetsByOwnerID(ses)
	api.FindSensorsByPetIDHandler = handler.FindSensorsByPetID(ses)
	api.FindSensorDataBySensorIDAndTimeRangeHandler = handler.FindSensorDataBySensorIDAndTimeRange(ses)
	api.FindSensorAvgBySensorIDAndDayHandler = handler.FindSensorAvgBySensorIDAndDay(ses)

	api.PreServerShutdown = func() {}

	api.ServerShutdown = func() { ses.Close() }

	return setupGlobalMiddleware(api.Serve(setupMiddlewares))
}

// The TLS configuration before HTTPS server starts.
func configureTLS(tlsConfig *tls.Config) {
	// Make all necessary changes to the TLS configuration here.
}

// As soon as server is initialized but not run yet, this function will be called.
// If you need to modify a config, store server instance to stop it individually later, this is the place.
// This function can be called multiple times, depending on the number of serving schemes.
// scheme value will be set accordingly: "http", "https" or "unix"
func configureServer(s *http.Server, scheme, addr string) {
}

// The middleware configuration is for the handler executors. These do not apply to the swagger.json document.
// The middleware executes after routing but before authentication, binding and validation
func setupMiddlewares(handler http.Handler) http.Handler {
	return handler
}

// The middleware configuration happens before anything, this middleware also applies to serving the swagger.json document.
// So this is a good place to plug in a panic handling middleware, logging and metrics
func setupGlobalMiddleware(handler http.Handler) http.Handler {
	return handler
}
