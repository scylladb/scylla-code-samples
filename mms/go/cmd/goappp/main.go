package main

import (
	"goapp/internal/log"
	"goapp/internal/scylla"

	"github.com/gocql/gocql"
	"go.uber.org/zap"
)

func main() {
	logger := log.CreateLogger("info")

	cluster := scylla.CreateCluster(gocql.Quorum, "catalog", "scylla-node1", "scylla-node2", "scylla-node3")
	session, err := gocql.NewSession(*cluster)
	if err != nil {
		logger.Fatal("unable to connect to scylla", zap.Error(err))
	}
	defer session.Close()

	scylla.SelectQuery(session, logger)
	insertQuery(session, "Mike", "Tyson", "12345 Foo Lane", "http://www.facebook.com/mtyson", logger)
	insertQuery(session, "Alex", "Jones", "56789 Hickory St", "http://www.facebook.com/ajones", logger)
	scylla.SelectQuery(session, logger)
	deleteQuery(session, "Mike", "Tyson", logger)
	scylla.SelectQuery(session, logger)
	deleteQuery(session, "Alex", "Jones", logger)
	scylla.SelectQuery(session, logger)
}

func insertQuery(session *gocql.Session, firstName, lastName, address, pictureLocation string, logger *zap.Logger) {
	logger.Info("Inserting " + firstName + "......")
	if err := session.Query("INSERT INTO mutant_data (first_name,last_name,address,picture_location) VALUES (?,?,?,?)", firstName, lastName, address, pictureLocation).Exec(); err != nil {
		logger.Error("insert catalog.mutant_data", zap.Error(err))
	}
}

func deleteQuery(session *gocql.Session, firstName string, lastName string, logger *zap.Logger) {
	logger.Info("Deleting " + firstName + "......")
	if err := session.Query("DELETE FROM mutant_data WHERE first_name = ? and last_name = ?", firstName, lastName).Exec(); err != nil {
		logger.Error("delete catalog.mutant_data", zap.Error(err))
	}
}
