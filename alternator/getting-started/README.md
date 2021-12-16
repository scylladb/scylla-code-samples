# Scylla Alternator Getting Started Example
Instructions for setting up a one node Scylla cluster and performing some basic operations on it using the Alternator API. More info in the Scylla University Course [Scylla Alternator](https://university.scylladb.com/courses/scylla-alternator/lessons/dynamodb-api-compatibility-project-alternator-basics/). 

### Starting a Scylla Cluster
To get Scylla up and running with Alternator enabled, start a local scylla instance:
```bash
docker run  --name some-scylla   --hostname some-scylla -p 8000:8000  -d scylladb/scylla:4.5.0    --smp 1 --memory=750M --overprovisioned 1 --alternator-port=8000
```

### Installing the Boto 3 Python library
Next, if you don’t already have it set up, install boto3 python library which also contains drivers for DynamoDB:
```bash
sudo pip install --upgrade boto3
```

### Running the Example Application
The application connects to the Scylla cluster, creates a table, inserts two rows into the created table and reads those two rows from the database. 
In the three scripts create.py read.py and write.py change the value for “endpoint_url” to the IP address of the node. 
To run it:
```bash
python create.py
python write.py
python read.py
```

### Destroying the Scylla Cluster
```bash
docker-compose kill
docker-compose rm -f
```

