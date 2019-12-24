package main

import (
	"flag"
	"fmt"
	"goapp/internal/log"
	"goapp/internal/scylla"
	"io/ioutil"
	"strings"

	"github.com/gocql/gocql"
	"github.com/qeesung/image2ascii/convert"
	"go.uber.org/zap"
)

var (
	alter bool
)

func init() {
	flag.BoolVar(&alter, "alter", true, "issue alter statements")
}
func main() {
	flag.Parse()

	logger := log.CreateLogger("info")

	cluster := scylla.CreateCluster(gocql.Quorum, "catalog", "scylla-node1", "scylla-node2", "scylla-node3")
	session, err := gocql.NewSession(*cluster)
	if err != nil {
		logger.Fatal("unable to connect to scylla", zap.Error(err))
	}
	defer session.Close()

	if alter {
		alterSchema(session, logger)
	}

	mutants := []string{"Jim Jefferies", "Bob Loblaw", "Bob Zemuda"}
	for _, mutant := range mutants {
		names := strings.SplitN(mutant, " ", 2)
		firstName := names[0]
		lastName := names[1]
		logger.Info("Processing file for " + firstName + "_" + lastName)
		insertFile(session, firstName, lastName, logger)
		readFile(session, firstName, lastName, logger)
	}
}

func readFile(session *gocql.Session, firstName string, lastName string, logger *zap.Logger) {
	var (
		m map[string][]byte
		b []byte
	)
	if err := session.Query("SELECT m,b from mutant_data WHERE first_name=? AND last_name=?", firstName, lastName).Scan(&m, &b); err != nil {
		logger.Fatal("unable to read image", zap.String("first_name", firstName), zap.String("last_name", lastName), zap.Error(err))
	}
	logger.Info("file metadata", zap.Any("properties", m))
	if err := ioutil.WriteFile("/tmp/"+firstName+"_"+lastName+".jpg", b, 0644); err != nil {
		logger.Fatal("unable to write image", zap.String("name", "/tmp/"+firstName+"_"+lastName+".jpg"), zap.Error(err))
	}
	convertOptions := convert.DefaultOptions
	convertOptions.FixedWidth = 100
	convertOptions.FixedHeight = 40

	converter := convert.NewImageConverter()
	fmt.Print(converter.ImageFile2ASCIIString("/tmp/"+firstName+"_"+lastName+".jpg", &convertOptions))
}

func alterSchema(session *gocql.Session, logger *zap.Logger) {
	if err := session.Query("ALTER table catalog.mutant_data ADD m map<text, blob>").Exec(); err != nil {
		logger.Fatal("altering table failed, forgot the '-alter=false' program argument?", zap.Error(err))
	}
	if err := session.Query("ALTER table catalog.mutant_data ADD b blob").Exec(); err != nil {
		logger.Fatal("altering table failed, forgot the '-alter=false' program argument?", zap.Error(err))
	}
}

func insertFile(session *gocql.Session, firstName, lastName string, logger *zap.Logger) {
	fName := "/usr/share/icons/mms/" + firstName + "_" + lastName + ".jpg"
	b, err := ioutil.ReadFile(fName)
	if err != nil {
		logger.Fatal("unable to read file", zap.String("file_name", fName), zap.Error(err))
	}

	m := readMetaFromFile(firstName+"_"+lastName, b)

	if err := session.Query("INSERT INTO mutant_data (first_name,last_name,b,m) VALUES (?,?,?,?)", firstName, lastName, b, m).Exec(); err != nil {
		logger.Error("insert catalog.mutant_data", zap.Error(err))
	}
}

func readMetaFromFile(name string, bytes []byte) map[string][]byte {
	return map[string][]byte{
		"name": []byte(name),
	}
}
