package main

import (
	"os"
	"time"

	"github.com/gocql/gocql"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

func createLogger(level string) *zap.Logger {
	lvl := zap.NewAtomicLevel()
	if err := lvl.UnmarshalText([]byte(level)); err != nil {
		lvl.SetLevel(zap.InfoLevel)
	}
	encoderCfg := zap.NewDevelopmentEncoderConfig()
	logger := zap.New(zapcore.NewCore(
		zapcore.NewConsoleEncoder(encoderCfg),
		zapcore.Lock(os.Stdout),
		lvl,
	))
	return logger
}

func createCluster(consistency gocql.Consistency, keyspace string, hosts ...string) *gocql.ClusterConfig {
	retryPolicy := &gocql.ExponentialBackoffRetryPolicy{
		Min:        time.Second,
		Max:        10 * time.Second,
		NumRetries: 5,
	}
	cluster := gocql.NewCluster(hosts...)
	cluster.Keyspace = keyspace
	cluster.Timeout = 5 * time.Second
	cluster.RetryPolicy = retryPolicy
	cluster.Consistency = consistency
	cluster.PoolConfig.HostSelectionPolicy = gocql.TokenAwareHostPolicy(gocql.RoundRobinHostPolicy())
	return cluster
}

type App struct {
	session *gocql.Session
	logger  *zap.Logger
}

func NewApp() *App {
	logger := createLogger("info")
	cluster := createCluster(gocql.Quorum, "catalog", "localhost:9042", "localhost:9043", "localhost:9044")
	session, err := gocql.NewSession(*cluster)
	if err != nil {
		logger.Fatal("unable to connect to scylla", zap.Error(err))
	}
	return &App{
		session: session,
		logger:  logger,
	}
}

func (app *App) showMutantData() {
	app.logger.Info("Data that we have in the catalog")
	q := app.session.Query("SELECT first_name,last_name FROM mutant_data")
	var firstName, lastName string
	it := q.Iter()
	defer func() {
		if err := it.Close(); err != nil {
			app.logger.Warn("select catalog.mutant", zap.Error(err))
		}
	}()
	for it.Scan(&firstName, &lastName) {
		app.logger.Info(firstName + " " + lastName)
	}
}

func (app *App) deleteMutant(firstName, lastName string) {
	app.logger.Info("Deleting " + firstName + " " + lastName)
	if err := app.session.Query("DELETE FROM mutant_data WHERE first_name = ? and last_name = ?", firstName, lastName).Exec(); err != nil {
		app.logger.Error("delete catalog.mutant_data", zap.Error(err))
	}
	app.logger.Info("Deleted.")
}

func (app *App) checkForMutant(firstName, lastName string) bool {
	var count int
	if err := app.session.Query("SELECT COUNT(*) FROM mutant_data WHERE first_name = ? and last_name = ?", firstName, lastName).Scan(&count); err != nil {
		app.logger.Error("check for mutant", zap.Error(err))
		return false
	}
	return count > 0
}

func (app *App) stop() {
	app.session.Close()
}

func (app *App) addMutant(firstName, lastName, address, pictureLocation string) {
	// TODO: Implement this function
	// You need to add an INSERT query here to add the mutant to the database
	panic("You need to implement the 'addMutant' function")
}

func main() {
	app := NewApp()
	defer app.stop()
	
	app.addMutant("Miles", "Morales", "42 Brooklyn St", "https://tinyurl.com/milesmorales123")
	app.showMutantData()
	if app.checkForMutant("Miles", "Morales") {
		app.logger.Info("Congratulations! You've successfully added Miles in the mutant database and have passed the challenge!")
	}
} 