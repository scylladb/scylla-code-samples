General Info and Prerequisites
==============================

The following Flink program will use a ```movies.csv``` file as incoming stream. The file contains approx. 9100 movie titles and a list of their genres. It will filter out only the movies with "Action" genre and send the results into your Scylla cluster.

The code was written and tested on Ubuntu 16.04 using Java8, with a Scylla node running version 2.2 RC2 on Centos7

**Prerequisites**
- [Java 8 installed](http://openjdk.java.net/install/) -> Install Java 8 JDK: ```sudo apt install openjdk-8-jdk-headless```
- Maven installed: ```sudo apt install maven```
- An instance to be used for Flink and the application code.
- [Scylla cluster up and running](https://www.scylladb.com/download/) - can be a single node.



Instructions
============

1. Download Flink

```curl -L -O http://apache.mivzakim.net/flink/flink-1.5.0/flink-1.5.0-bin-scala_2.11.tgz```

2. Extract archive

```tar xvzf flink-1.5.0-bin-scala_2.11.tgz```

3. Start / Stop Flink

	a. ```cd flink-1.5.0/```

	b. ```./bin/start-cluster.sh``` | ```./bin/stop-cluster.sh```

4. Maven create project quickstart (if needed)

```mvn archetype:generate -DgroupId=com.scylla.movies -DartifactId=flink-app -DarchetypeArtifactId=flink-quickstart-java -DarchetypeGroupId=org.apache.flink -DarchetypeVersion=1.5.0```

5. Download/clone this repo (```movies.csv``` file + flink code). Code is already in a Maven project structure

6. Set the Scylla node IP to your Scylla node

	a. Go into ```flink-app``` folder. Run ```vi src/main/java/com/scylla/movies/FilterMoviesStreamingJob.java```

	b. Edit ```.setHost("[scylla_node_IP]")``` and place your Scylla node IP

7. Set the path to the location of the ```movies.csv``` file. In my case it was under ```flink-1.5.0/data/``` folder

	a. Go into ```flink-app``` folder. Run ```vi src/main/java/com/scylla/movies/FilterMoviesStreamingJob.java```

	b. Edit ```env.readTextFile("[full_path_to_csv]");``` and set the full path to the ```movies.csv``` file

8. Compile the code

Go into ```flink-app``` folder. Run ```mvn install```

9. Create the following schema on Scylla using ```cqlsh```

```
CREATE KEYSPACE flink_example WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '1'}  AND durable_writes = true;

CREATE TABLE flink_example.movies (
    title text PRIMARY KEY,
    genres list<text>
) WITH bloom_filter_fp_chance = 0.01
    AND caching = {'keys': 'ALL', 'rows_per_partition': 'ALL'}
    AND comment = ''
    AND compaction = {'class': 'SizeTieredCompactionStrategy'}
    AND compression = {}
    AND crc_check_chance = 1.0
    AND dclocal_read_repair_chance = 0.1
    AND default_time_to_live = 0
    AND gc_grace_seconds = 864000
    AND max_index_interval = 2048
    AND memtable_flush_period_in_ms = 0
    AND min_index_interval = 128
    AND read_repair_chance = 0.0
    AND speculative_retry = '99.0PERCENTILE';
```

10. Run the Flink program

	a. Go into ```flink-1.5.0``` folder

	b. Run ```./bin/flink run [full_path]/flink-app-1.0-SNAPSHOT.jar```


**Results in Scylla**

You should have 1544 entries in Scylla.

```
cqlsh> select count (*) from flink_example.movies ;

 count
-------
  1544
```

**Example of entry**

 ```
title                 | genres
-----------------------+----------------------------------------------------------
 Doctor Strange (2007) | ['Action', 'Animation', 'Children', 'Fantasy', 'Sci-Fi']
```
