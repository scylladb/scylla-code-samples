## Scylla in Docker for the [Mutant Monitoring University Course](https://university.scylladb.com/courses/the-mutant-monitoring-system-training-course/)

### Instructions for setting up a Scylla Cluster from this repo. For more details check out the [Using Scylla Drivers](https://university.scylladb.com/courses/using-scylla-drivers/) and [Mutant Monitoring System](https://university.scylladb.com/courses/the-mutant-monitoring-system-training-course/) courses in Scylla University.

```
cd mms
docker-compose up -d
```

Run bash in the node:
```
docker exec -it scylla-node1 bash
```

Followed by scylla commands, like
```
> nodetool status
```
or
```
> cqlsh
```

### To manually add the tracking keyspace and data:
```
docker exec -it scylla-node1 cqlsh
```

```
CREATE KEYSPACE tracking WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy','DC1' : 3};
use tracking;
CREATE TABLE tracking_data (
       first_name text,
       last_name text,
       timestamp timestamp,
       location varchar,
       speed double,
       heat double,
       telepathy_powers int,
       primary key((first_name, last_name), timestamp))
       WITH CLUSTERING ORDER BY (timestamp DESC)
       AND default_time_to_live = 72000 
       AND gc_grace_seconds = 0
       AND COMPACTION = {'class': 'TimeWindowCompactionStrategy',
                                  'compaction_window_unit' : 'HOURS',
                                  'compaction_window_size' : 1}; 
```

```
INSERT INTO tracking.tracking_data ("first_name","last_name","timestamp","location","speed","heat","telepathy_powers") VALUES ('Jim','Jeffries','2017-11-11 08:05+0000','New York',1.0,3.0,17) ;
INSERT INTO tracking.tracking_data ("first_name","last_name","timestamp","location","speed","heat","telepathy_powers") VALUES ('Jim','Jeffries','2017-11-11 09:05+0000','New York',2.0,4.0,27) ;
INSERT INTO tracking.tracking_data ("first_name","last_name","timestamp","location","speed","heat","telepathy_powers") VALUES ('Jim','Jeffries','2017-11-11 10:05+0000','New York',3.0,5.0,37) ;
INSERT INTO tracking.tracking_data ("first_name","last_name","timestamp","location","speed","heat","telepathy_powers") VALUES ('Jim','Jeffries','2017-11-11 10:22+0000','New York',4.0,12.0,47) ;
INSERT INTO tracking.tracking_data ("first_name","last_name","timestamp","location","speed","heat","telepathy_powers") VALUES ('Jim','Jeffries','2017-11-11 11:05+0000','New York',4.0,9.0,87) ;
INSERT INTO tracking.tracking_data ("first_name","last_name","timestamp","location","speed","heat","telepathy_powers") VALUES ('Jim','Jeffries','2017-11-11 12:05+0000','New York',4.0,24.0,57) ;
```


### Destroying the Scylla Cluster 
```
cd mms
docker-compose kill
docker-compose rm -f
```
### Importing the MMS keyspaces and data automatically 

```
docker exec scylla-node1 cqlsh -f /mutant-data.txt
```

The data will be imported after a few seconds.

