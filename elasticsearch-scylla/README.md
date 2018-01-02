# Mine data with Elasticsearch and ScyllaDB
<p align=center>

The purpose of this demo is to show how to feed data from Twitter into Elasticsearch and Scylla for data analytics purposes. The Twitter app will search for a specific Twitter hashtag and feed data into Scylla. To feed the data from Scylla to Elasticsearch, simply issue a curl command referenced in this README to begin the data dump.

### Architecture

##### Scylla Architecture
Three Scylla 2.x nodes

##### Elasticsearch Architecture
Two Elasticsearch nodes (Master, data).
![Pic](https://raw.githubusercontent.com/scylla/scylla-code-samples/master/elasticsearch-scylla/diagram.png)

### Prerequisites

1. Docker for [Mac](https://download.docker.com/mac/stable/Docker.dmg) or [Windows](https://download.docker.com/win/stable/InstallDocker.msi).
2. This Git [Repo](https://github.com/rusher81572/elasticsearch-scylla/archive/master.zip)
3. 3GB of RAM or greater for Docker
4. (Optional) [Twitter API credentials](https://dev.twitter.com/)

### Building the images
```
unzip elasticsearch-scylla-master.zip
cd elasticsearch-scylla
docker-compose build
```

To use the Twitter app to mine data from Twitter, modify the twitter section of docker-compose.yml with your developer API credentials and desired Twitter topic.

### Starting the containers
```
docker-compose up -d
```

Please wait about a minute for all the services to start properly.

### Check the status of the containers
```
docker ps
```

You should see the following containers running:

```
CONTAINER ID        IMAGE                                      COMMAND                  CREATED             STATUS              PORTS                    NAMES
b5e5cb9a536f        elasticsearchscylla_kibana                 "/bin/sh -c 'cd /k..."   49 seconds ago      Up 46 seconds       0.0.0.0:5601->5601/tcp   elasticsearchscylla_kibana_1
a4a18e3ba26f        elasticsearchscylla_scylla-node3           "/bin/sh -c 'bash ..."   49 seconds ago      Up 46 seconds                                elasticsearchscylla_scylla-node3_1
3214c275b49d        elasticsearchscylla_twitter                "/bin/sh -c 'npm i..."   49 seconds ago      Up 47 seconds                                elasticsearchscylla_twitter_1
0d7f66c4b1c9        elasticsearchscylla_elasticsearch-slave1   "/bin/sh -c 'bash ..."   49 seconds ago      Up 46 seconds                                elasticsearchscylla_elasticsearch-slave1_1
b5b04ac809b8        elasticsearchscylla_elasticsearch-master   "/bin/sh -c 'bash ..."   49 seconds ago      Up 45 seconds       0.0.0.0:9200->9200/tcp   elasticsearchscylla_elasticsearch-master_1
f4e03f46a8ea        elasticsearchscylla_scylla-node2           "/bin/sh -c 'bash ..."   49 seconds ago      Up 47 seconds                                elasticsearchscylla_scylla-node2_1
d2bfecf52f4d        elasticsearchscylla_scylla-node1           "/bin/sh -c 'bash ..."   49 seconds ago      Up 46 seconds                                elasticsearchscylla_scylla-node1_1
```

### Checking the Twitter data from Scylla with cqlsh
```
docker exec -it elasticsearchscylla_scylla-node1_1 cqlsh
cqlsh> select * from twitter.tweets;
```

### Dumping the data from Scylla to Elasticsearch
```
curl http://127.0.0.1:8080/dump
```
Each time a dump is done, the data in Elasticsearch is deleted.

### To stop the tweets from writing to Scylla
```
curl http://127.0.0.1:8080/stop
```

### To start writing the tweets to Scylla again
```
curl http://127.0.0.1:8080/start
```

### Accessing Kibana to view the Twitter data
1. Goto https://0.0.0.0:5601 in your web browser
2. Enter logstash for the index name and then click the create button
3. Start analyzing data

### Stopping and Erasing the demo

The following commands will stop and delete all running containers.

```
docker-compose kill
docker-compose rm -f
```

To start the demo again, simply run:
```
docker-compose up -d
```
