Billy - A Scylla example application to work with and benchmark sensor data
===========================================================================

This is a distributed reader for Scylla, designed to demonstrate and benchmark
Scylla read capabilities on a dataset that approximates real-life IoT sensor data.

The data generated emulates a number of sensors each sending a temperature reading to
the central database every minute. The database expects the following schema:

```
CREATE TABLE billy.readings (
    sensor_id int,
    date date,
    time time,
    temperature int,
    PRIMARY KEY ((sensor_id, date), time)
)
```

So the `sensor_id` and `date` are the partition key, allowing queries that retrieve some or all of the
data points for a particular day, like

```
  SELECT * from readings where sensor_id=1 and date='2019-01-01';
```

With 1440 minutes to a day, at the end of each day each partition will have at most 1440 clustering keys,
each pointing to a temperature reading.

Basic Architecture
==================

The application is designed to facilitate the distribution of work among many loaders, and is comprised of two parts:

 1. A server binary that is installed in each loader and will connect to the Scylla database and perform the read operations,
 2. a coordinator binary that will contact the server binaries in the loaders and spread the work among them.

There is also a populator binary distributed alongside this suite, that generates the data randomly and inserts it
into Scylla.

Building
========

To build it:

```
 $ go build cmd/server/server.go # builds the server binary
 $ go build cmd/reader/read.go   # builds the coordinator binary
 $ go build cmd/populator/pop.go # builds the data populator
```

Running the server binary
=========================

In each of the loader machines, execute:

```
 $ ./server -bind listen_ip:port -node scylla_ip -logfile serverlog.txt
```

The server binary must be running in all loader machines in which the test is intended
to run.

The coordinator machine (from which population and reader will be executed), must then
point to all server binaries in a file called `hosts.txt`, listing one server per line with
`ip:port` format. For example:

```
$ cat hosts.txt
localhost:20000
localhost:20001
```

Populating
==========

The tool expects the keyspace and tables to have been already created and adhere to a specified schema. The file
`billy.cql` is distributed with this repository, so to create the needed schema, do:

```
 $ cqlsh scylla_ip -f billy.cql
```

Once the schema is created we can execute the `pop` command in the coordinator machine to populate the data.

For example, to populate the database with data from 1,000 sensors from January 1st 2019 to January 31st 2019,
execute:

```
 $ ./pop -startdate 2019-01-01 -enddate 2019-01-31 -startkey 1 -endkey 1000 -hosts hosts.txt
```

Reading
========

Once the database is populated, we can execute the reader binary in the coordinator machine as

```
 $ ./read -startdate 2019-01-01 -enddate 2019-01-31 -startkey 1 -endkey 1000 -hosts hosts.txt -output output.txt
```

Alternatively, the user can skip a particular sensor ID by adding the option

```
 -exclude <sensor_id>
```

It is also possible to control whether the read should be sequential, reverse, or random with the `-sweep` parameter
