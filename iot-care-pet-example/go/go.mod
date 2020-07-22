module github.com/scylladb/scylla-code-samples/iot-care-pet-example/go

go 1.14

require (
	github.com/codahale/hdrhistogram v0.0.0-20161010025455-3a0bb77429bd
	github.com/go-openapi/errors v0.19.6
	github.com/go-openapi/loads v0.19.5
	github.com/go-openapi/runtime v0.19.20
	github.com/go-openapi/spec v0.19.9
	github.com/go-openapi/strfmt v0.19.5
	github.com/go-openapi/swag v0.19.9
	github.com/go-openapi/validate v0.19.10
	github.com/gocql/gocql v0.0.0-20200624222514-34081eda590e
	github.com/jessevdk/go-flags v1.4.0
	github.com/scylladb/gocqlx/v2 v2.1.0
	github.com/spf13/pflag v1.0.5
	golang.org/x/net v0.0.0-20200707034311-ab3426394381
)

replace github.com/gocql/gocql => github.com/scylladb/gocql v1.4.0
