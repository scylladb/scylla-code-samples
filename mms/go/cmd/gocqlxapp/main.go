package main

import (
	"goapp/internal/log"
	"goapp/internal/scylla"

	"github.com/gocql/gocql"
	"github.com/scylladb/gocqlx"
	"github.com/scylladb/gocqlx/qb"
	"github.com/scylladb/gocqlx/table"
	"go.uber.org/zap"
)

var (
	deleteStmt  string
	deleteNames []string

	insertStmt  string
	insertNames []string

	selectStmt  string
	selectNames []string

	tbl *table.Table
)

type Record struct {
	FirstName       string `db:"first_name"`
	LastName        string `db:"last_name"`
	Address         string `db:"address"`
	PictureLocation string `db:"picture_location"`
}

func init() {
	m := table.Metadata{
		Name:    "mutant_data",
		Columns: []string{"first_name", "last_name", "address", "picture_location"},
		PartKey: []string{"first_name", "last_name"},
	}
	tbl = table.New(m)

	deleteStmt, deleteNames = tbl.Delete()
	insertStmt, insertNames = tbl.Insert()
	// Normally a select statement such as this would use `tbl.Select()` to select by
	// primary key but now we just want to display all the records...
	selectStmt, selectNames = qb.Select(m.Name).Columns(m.Columns...).ToCql()
}

func main() {
	logger := log.CreateLogger("info")

	cluster := scylla.CreateCluster(gocql.Quorum, "catalog", "scylla-node1", "scylla-node2", "scylla-node3")
	session, err := gocql.NewSession(*cluster)
	if err != nil {
		logger.Fatal("unable to connect to scylla", zap.Error(err))
	}
	defer session.Close()

	selectQuery(session, logger)
	insertQuery(session, "Mike", "Tyson", "12345 Foo Lane", "http://www.facebook.com/mtyson", logger)
	insertQuery(session, "Alex", "Jones", "56789 Hickory St", "http://www.facebook.com/ajones", logger)
	selectQuery(session, logger)
	deleteQuery(session, "Mike", "Tyson", logger)
	selectQuery(session, logger)
	deleteQuery(session, "Alex", "Jones", logger)
	selectQuery(session, logger)
}

func deleteQuery(session *gocql.Session, firstName string, lastName string, logger *zap.Logger) {
	logger.Info("Deleting " + firstName + "......")
	r := Record{
		FirstName: firstName,
		LastName:  lastName,
	}
	if err := gocqlx.Query(session.Query(deleteStmt), deleteNames).BindStruct(r).ExecRelease(); err != nil {
		logger.Error("delete catalog.mutant_data", zap.Error(err))
	}
}

func insertQuery(session *gocql.Session, firstName, lastName, address, pictureLocation string, logger *zap.Logger) {
	logger.Info("Inserting " + firstName + "......")
	r := Record{
		FirstName:       firstName,
		LastName:        lastName,
		Address:         address,
		PictureLocation: pictureLocation,
	}
	if err := gocqlx.Query(session.Query(insertStmt), insertNames).BindStruct(r).ExecRelease(); err != nil {
		logger.Error("insert catalog.mutant_data", zap.Error(err))
	}
}

func selectQuery(session *gocql.Session, logger *zap.Logger) {
	logger.Info("executing", zap.String("query", selectStmt))
	logger.Info("Displaying Results:")
	var rs []Record
	if err := gocqlx.Query(session.Query(selectStmt), selectNames).SelectRelease(&rs); err != nil {
		logger.Warn("select catalog.mutant", zap.Error(err))
		return
	}
	for _, r := range rs {
		logger.Info("\t" + r.FirstName + " " + r.LastName + ", " + r.Address + ", " + r.PictureLocation)
	}
}
