## Scylla in Docker for the [Mutant Monitoring University Course](https://university.scylladb.com/courses/the-mutant-monitoring-system-training-course/) - Scala Lessons 1 2 and 3

### Instructions for setting up a Scylla Cluster from this repo, prerequisites are a running 3 node cluster with the catalog/tracking keyspaces and tables. More info in the Scylla University course [Using Scylla Drivers](https://university.scylladb.com/courses/using-scylla-drivers/). 

```
cd mms/scala/
docker build -t scala-app .
docker run -d --net=mms_web --name some-scala-app scala-app
docker exec -it some-scala-app sh
java -jar scala-app/target/scala-2.13/mms-scala-app-assembly-0.1.0-SNAPSHOT.jar
```

### To manually add the catalog keyspace and data
docker exec -it mms_scylla-node1_1 cqlsh
CREATE KEYSPACE catalog WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy','DC1' : 3};
use catalog;
CREATE TABLE mutant_data ( first_name text, last_name text, address text, picture_location text, PRIMARY KEY((first_name, last_name)));

insert into mutant_data ("first_name","last_name","address","picture_location") VALUES ('Bob','Loblaw','1313 Mockingbird Lane', 'http://www.facebook.com/bobloblaw'); insert into mutant_data ("first_name","last_name","address","picture_location") VALUES ('Bob','Zemuda','1202 Coffman Lane', 'http://www.facebook.com/bzemuda'); insert into mutant_data ("first_name","last_name","address","picture_location") VALUES ('Jim','Jeffries','1211 Hollywood Lane', 'http://www.facebook.com/jeffries');


### Destroying the Scylla Cluster 
```
cd mms
docker-compose kill
docker-compose rm -f
```

