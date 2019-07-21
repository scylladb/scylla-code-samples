## Scylla in Docker for the Mutant Monitoring University Course - Java Lessons 1 2 and 3

### Instructions for setting up a Scylla Cluster from this repo, prerequisites are a running 3 node cluster with the catalog/tracking keyspaces and tables. More info in the University Lessons. 

```
cd mms2/java/<dir name>
docker build -t java-app .
docker run -d --net=mms2_web --name some-java-app java-app
docker exec -it some-java-app sh
cd <dir-name>/dist
java -jar <AppName>.jar
```

### Destroying the Scylla Cluster 
```
cd mms2
docker-compose kill
docker-compose rm -f
```

