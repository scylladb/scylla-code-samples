package main

import (
	"goapp/internal/log"
	"goapp/internal/scylla"

	"github.com/gocql/gocql"
	"github.com/scylladb/gocqlx/v2"
	"github.com/scylladb/gocqlx/v2/qb"
	"github.com/scylladb/gocqlx/v2/table"
	"go.uber.org/zap"
)

type Record struct {
	FirstName string `db:"first_name"`
	LastName  string `db:"last_name"`
	Address   string `db:"address"`
}

func main() {
	logger := log.CreateLogger("info")

	cluster := scylla.CreateCluster(gocql.Quorum, "catalog", "localhost:9042", "localhost:9043", "localhost:9044")
	session, err := gocql.NewSession(*cluster)
	if err != nil {
		logger.Fatal("unable to connect to scylla", zap.Error(err))
	}
	defer session.Close()

	// Create table metadata
	m := table.Metadata{
		Name:    "mutant_data",
		Columns: []string{"first_name", "last_name", "address"},
		PartKey: []string{"first_name", "last_name"},
	}
	tbl := table.New(m)

	// Insert a record
	insertStmt, insertNames := tbl.Insert()
	r := Record{
		FirstName: "Alice",
		LastName:  "Smith",
		Address:   "456 Oak Ave",
	}
	
	err = gocqlx.Query(session.Query(insertStmt), insertNames).BindStruct(r).ExecRelease()
	if err != nil {
		logger.Error("insert failed", zap.Error(err))
		return
	}
	logger.Info("Inserted Alice Smith")

	// Select all records using qb
	selectStmt, selectNames := qb.Select(m.Name).Columns(m.Columns...).ToCql()
	var results []Record
	err = gocqlx.Query(session.Query(selectStmt), selectNames).SelectRelease(&results)
	if err != nil {
		logger.Error("select failed", zap.Error(err))
		return
	}

	logger.Info("Retrieved records:")
	for _, r := range results {
		logger.Info("Record", zap.String("name", r.FirstName+" "+r.LastName), zap.String("address", r.Address))
	}
} 