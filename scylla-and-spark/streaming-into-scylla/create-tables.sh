#!/bin/bash

set -e
set -x

docker-compose exec scylla cqlsh -e "DROP KEYSPACE IF EXISTS quotes;"
docker-compose exec scylla cqlsh -e "CREATE KEYSPACE quotes WITH REPLICATION = {'class': 'SimpleStrategy', 'replication_factor': 1};"
docker-compose exec scylla cqlsh -e "CREATE TABLE quotes.quotes (symbol TEXT, timestamp TIMESTAMP, day TIMESTAMP, latest_price DOUBLE, previous_close DOUBLE, latest_volume BIGINT, PRIMARY KEY ((symbol), timestamp));"
docker-compose exec scylla cqlsh -e "CREATE MATERIALIZED VIEW quotes.quotes_by_day AS SELECT * FROM quotes.quotes WHERE symbol IS NOT NULL AND timestamp IS NOT NULL PRIMARY KEY ((day), symbol, timestamp)"
