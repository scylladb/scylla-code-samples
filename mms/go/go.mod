module goapp

go 1.24

require (
	github.com/gocql/gocql v0.0.0-20211015133455-b225f9b53fa1
	github.com/qeesung/image2ascii v1.0.1
	github.com/scylladb/gocqlx/v2 v2.8.0
	go.uber.org/zap v1.13.0
)

require (
	github.com/BurntSushi/toml v0.3.1 // indirect
	github.com/aybabtme/rgbterm v0.0.0-20170906152045-cc83f3b3ce59 // indirect
	github.com/golang/snappy v0.0.4 // indirect
	github.com/hailocab/go-hostpool v0.0.0-20160125115350-e80d13ce29ed // indirect
	github.com/mattn/go-isatty v0.0.10 // indirect
	github.com/nfnt/resize v0.0.0-20180221191011-83c6a9932646 // indirect
	github.com/scylladb/go-reflectx v1.0.1 // indirect
	github.com/wayneashleyberry/terminal-dimensions v1.0.0 // indirect
	go.uber.org/atomic v1.5.0 // indirect
	go.uber.org/multierr v1.3.0 // indirect
	go.uber.org/tools v0.0.0-20190618225709-2cfd321de3ee // indirect
	golang.org/x/lint v0.0.0-20190930215403-16217165b5de // indirect
	golang.org/x/sys v0.0.0-20191008105621-543471e840be // indirect
	golang.org/x/tools v0.0.0-20191029190741-b9c20aec41a5 // indirect
	gopkg.in/inf.v0 v0.9.1 // indirect
	honnef.co/go/tools v0.0.1-2019.2.3 // indirect
)

replace github.com/gocql/gocql => github.com/scylladb/gocql v1.3.1
