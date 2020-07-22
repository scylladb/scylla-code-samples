package main

import (
	"time"

	"github.com/spf13/pflag"

	"github.com/scylladb/scylla-code-samples/iot-care-pet-example/go/cmd/server/restapi"
)

var host = pflag.String("host", "localhost", "the IP to listen on")
var port = pflag.Int("port", 0, "the port to listen on for insecure connections, defaults to a random value")

func configure(server *restapi.Server) {
	server.CleanupTimeout = 10 * time.Second
	server.GracefulTimeout = 15 * time.Second
	server.MaxHeaderSize = 1024 * 1024

	server.SocketPath = "/var/run/care-pet.sock"

	server.Host = *host
	server.Port = *port

	server.ReadTimeout = 30 * time.Second
	server.WriteTimeout = 60 * time.Second
}
