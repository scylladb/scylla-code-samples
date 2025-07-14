package main

import (
	"goapp/internal/log"
	"goapp/internal/scylla"

	"github.com/gocql/gocql"
	"github.com/scylladb/gocqlx/v2"
	"github.com/scylladb/gocqlx/v2/table"
	"go.uber.org/zap"
)

// TODO: Define the Record struct with fields: first_name, last_name, address
// Use the `db` tag for each field

func main() {
	logger := log.CreateLogger("info")

	cluster := scylla.CreateCluster(gocql.Quorum, "catalog", "localhost:9042", "localhost:9043", "localhost:9044")
	session, err := gocql.NewSession(*cluster)
	if err != nil {
		logger.Fatal("unable to connect to scylla", zap.Error(err))
	}
	defer session.Close()

	// TODO: Create table metadata for mutant_data table
	// Columns: first_name, last_name, address
	// Partition key: first_name, last_name

	// TODO: Insert a record for "John Smith" with address "123 Main St"
	// Use gocqlx to insert the record

	// TODO: Insert another record for "Jane Doe" with address "456 Oak Ave"
	// Use gocqlx to insert the record

	logger.Info("Challenge completed successfully!")
} 