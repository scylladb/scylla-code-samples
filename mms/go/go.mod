module goapp

go 1.13

require (
	github.com/aybabtme/rgbterm v0.0.0-20170906152045-cc83f3b3ce59 // indirect
	github.com/gocql/gocql v0.0.0-20191106222750-ae2f7fc85f32
	github.com/mattn/go-isatty v0.0.10 // indirect
	github.com/nfnt/resize v0.0.0-20180221191011-83c6a9932646 // indirect
	github.com/qeesung/image2ascii v1.0.1
	github.com/scylladb/gocqlx v1.3.1
	github.com/wayneashleyberry/terminal-dimensions v1.0.0 // indirect
	go.uber.org/zap v1.13.0
)

replace github.com/gocql/gocql => github.com/scylladb/gocql v1.3.1
