module billy

go 1.12

require (
	github.com/gocql/gocql v0.0.0-20190922122429-7b17705d7514
	golang.org/x/text v0.3.2 // indirect
)

replace github.com/gocql/gocql => github.com/scylladb/gocql v1.3.0-rc.1
