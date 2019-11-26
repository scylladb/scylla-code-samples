module goapp

go 1.13

require (
	github.com/gocql/gocql v0.0.0-20191106222750-ae2f7fc85f32
	go.uber.org/zap v1.13.0
)

replace github.com/gocql/gocql => github.com/scylladb/gocql v1.3.1
