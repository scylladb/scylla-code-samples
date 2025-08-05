package main

import (
	"flag"
	"fmt"
	"goapp/internal/log"
	"goapp/internal/scylla"
	"io/ioutil"
	"os"
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

	cluster := scylla.CreateCluster(gocql.Quorum, "catalog", "localhost:9042", "localhost:9043", "localhost:9044")
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
		if len(names) < 2 {
			logger.Error("invalid name format", zap.String("mutant", mutant))
			continue
		}

		firstName := names[0]
		lastName := names[1]

		logger.Info("Processing file for " + firstName + "_" + lastName)

		if !insertFile(session, firstName, lastName, logger) {
			continue // skip reading if insert failed
		}

		readFile(session, firstName, lastName, logger)
	}
}

func readFile(session *gocql.Session, firstName string, lastName string, logger *zap.Logger) {
	var (
		m map[string][]byte
		b []byte
	)

	if err := session.Query("SELECT m, b FROM mutant_data" /* <- Update this query with WHERE clause */ , firstName, lastName).Scan(&m, &b); err != nil {
		logger.Fatal("unable to read image", zap.String("first_name", firstName), zap.String("last_name", lastName), zap.Error(err))
	}

	logger.Info("file metadata", zap.Any("properties", m))

	outputPath := "/tmp/" + firstName + "_" + lastName + ".jpg"
	if err := ioutil.WriteFile(outputPath, b, 0644); err != nil {
		logger.Fatal("unable to write image", zap.String("name", outputPath), zap.Error(err))
	}

	convertOptions := convert.DefaultOptions
	convertOptions.FixedWidth = 100
	convertOptions.FixedHeight = 40

	converter := convert.NewImageConverter()
	fmt.Print(converter.ImageFile2ASCIIString(outputPath, &convertOptions))
}

func alterSchema(session *gocql.Session, logger *zap.Logger) {
	if err := session.Query("ALTER TABLE catalog.mutant_data ADD m map<text, blob>").Exec(); err != nil {
		logger.Fatal("altering table failed (column 'm')", zap.Error(err))
	}
	if err := session.Query("ALTER TABLE catalog.mutant_data ADD b blob").Exec(); err != nil {
		logger.Fatal("altering table failed (column 'b')", zap.Error(err))
	}
}

func insertFile(session *gocql.Session, firstName, lastName string, logger *zap.Logger) bool {
	fName := "images/" + firstName + "_" + lastName + ".jpg"

	if _, err := os.Stat(fName); os.IsNotExist(err) {
		logger.Error("file does not exist", zap.String("file_name", fName))
		return false
	}

	b, err := ioutil.ReadFile(fName)
	if err != nil {
		logger.Fatal("unable to read file", zap.String("file_name", fName), zap.Error(err))
		return false
	}

	m := readMetaFromFile(firstName+"_"+lastName, b)

	if err := session.Query("INSERT INTO mutant_data (first_name, last_name, b, m) VALUES (?, ?, ?, ?)",
		firstName, lastName, b, m).Exec(); err != nil {
		logger.Error("insert catalog.mutant_data", zap.Error(err))
		return false
	}

	return true
}

func readMetaFromFile(name string, bytes []byte) map[string][]byte {
	return map[string][]byte{
		"name": []byte(name),
	}
}
