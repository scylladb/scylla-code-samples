# Create a quick Scylla Cluster for the Mutant Monitoring System (MMS)
<p align=center>

The purpose of this demo is to show how to quickly bring up a Scylla cluster in Docker.


##### Scylla Architecture
Three Scylla 1.7 nodes

### Prerequisites

1. Docker for [Mac](https://download.docker.com/mac/stable/Docker.dmg) or [Windows](https://download.docker.com/win/stable/InstallDocker.msi).
2. This Git repository
3. 3GB of RAM or greater for Docker
4. If you are using Linux, you will need [docker-compose](https://docs.docker.com/compose/install/).

### Building the images
```
git clone https://github.com/scylladb/scylla-code-samples.git
cd scylla-code-samples/mms
docker-compose build
```

### Starting the containers
```
docker-compose up -d
```

Please wait about a minute for all the services to start properly.


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
