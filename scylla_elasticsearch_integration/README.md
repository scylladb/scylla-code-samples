General Info and Prerequisites
==============================

The following example creates an apparel catalog stored on Scylla, and searchable using Elasticsearch (ES).      
We will be using two python scripts to demonstrate the integration of Scylla with Elasticsearch.

1. Dual writes using the “insert_data” script for data ingestion, in our case an apparel catalog csv file.
2. Textual search using the “query_data” script, a 2-hop query that will retrieve the unique product_id (SKU) from
   Elasticsearch and then use the SKU to retrieve all the other product attributes from Scylla.

**Prerequisites**

- [Python 2.7, 3.5, 3.6, 3.7 or 3.8 installed](https://www.python.org/download)
- [PIP installed](https://packaging.python.org/guides/installing-using-linux-tools/)
- [Docker](https://docs.docker.com/desktop/)
- [Scylla Cluster UP and Running](https://www.scylladb.com/download/)
- [ElasticSearch Cluster UP and Running](https://www.elastic.co/guide/en/elasticsearch/reference/current/docker.html)

Instructions
============

### 1. Setup Environment

First, spin a fresh ScyllaDB and ElasticSearch Cluster:

```sh
docker run -d --name scylla-elastic --publish '9042:9042' --rm -d scylladb/scylla:6.0.1 --overprovisioned 1 --smp 1

docker run -d --name elasticsearch -p 9200:9200 -e "discovery.type=single-node" -e "xpack.security.enabled=false" docker.elastic.co/elasticsearch/elasticsearch:8.14.3
```

To validate if your instance is up and running, you can use the following commands:

```sh
# ElasticSearch Health
curl http://127.0.0.1:9200/_cluster/health?pretty

# ScyllaDB Status
docker compose exec -it scylla-elastic notetool status
```

> [!NOTE]
> To check if ScyllaDB is up and running, after you run the command aboce you should see: **UN** (Up And Running)
> In the case of ElasticSearch, you should see a JSON response with the cluster health status.


If you're without a venv, create one:

```bash
python -m venv venv
source .venv/bin/activate
```

Then, make sure to install our Driver into your Python environment:

```bash
sudo pip install scylla-driver
sudo pip install elasticsearch
```

### 2. Running the App

Copy the files to the location from which you will run them, and make them executable

- catalog.csv (the SKU is the unique product_id, made of other product attributes initials)
- insert_data_into_scylla+elastic.py
- query_data_from_scylla+elastic.py

Run the *“insert_data”* script. The script will perform the following:

- Create the Schema on Scylla
- Create the Elasticsearch index
- Dual write: insert the catalog items (csv file) to both DBs (using prepared statement for Scylla)

> [!TIP]
> Use the ```-s | -e``` flags to insert a comma-separated list of IPs for the Scylla and Elasticsearch (ES) nodes.
> If you are running Elasticsearch (ES) on the same node as the python scripts, no need to enter IP, default 127.0.0.1
> will be used.

```bash
python insert_data_into_scylla+elastic.py -h
	# usage: insert_data_into_scylla+elastic.py [-h] [-s SCYLLA_IP] [-e ES_IP]

	# optional arguments:
	#  -h, --help    show this help message and exit
	#  -s SCYLLA_IP
	#  -e ES_IP
```

Once the *“insert_data”* script completes, you will find 160 entries in both Scylla and Elasticsearch

```
$ curl http://127.0.0.1:9200/catalog/_count/?pretty
{
  "count" : 160,
  "_shards" : {
    "total" : 5,
    "successful" : 5,
    "skipped" : 0,
    "failed" : 0
  }
}
```

On the CQLSH:

```cassandraql
SELECT COUNT(*)
FROM catalog.apparel;

----
-- count
-------
--   160
-- (1 rows)
```

Run the *“query_data”* script. The script will perform the following:

- Textual search in Elasticsearch using single / multiple filter/s, or no filter (match_all)
- Use the Elasticsearch results to query Scylla (using prepared statement)

> [!TIP]
> Use the ```-s | -e``` flags to insert a comma-separated list of IPs for the Scylla and Elasticsearch (ES) nodes.
> If you are running Elasticsearch (ES) on the same node as the python scripts, no need to enter IP, default 127.0.0.1
> will be used.

Use the ```-n``` flag to select the query type, the optional values are:

- **single**: using a single filter (by group) to query for *“pants”*
- **multiple (default)**: using multiple filters (by color and sub_group) to query for *"white softshell"*
- **none**: query without any filter = *match_all*

> [!NOTE]
> Elasticsearch returns only the 1st 10 results by default. To overcome this we set the size limit to 1000
> results. For large result we recommend using pagination (read more
> here: [elasticsearch-py helpers](http://elasticsearch-py.readthedocs.io/en/master/helpers.html?highlight=scroll)).

```bash 
python query_data_from_scylla+elastic.py -h
# usage: query_data_from_scylla+elastic.py [-h] [-s SCYLLA_IP] [-e ES_IP] [-n NUM_FILTERS]

# optional arguments:
#   -h, --help      show this help message and exit
#   -s SCYLLA_IP
#   -e ES_IP
#   -n NUM_FILTERS
```

To delete Elasticsearch index and the keyspace in Scylla run the following commands:

- **Elasticsearch**:  ```$ curl -X DELETE "127.0.0.1:9200/catalog"```
- **Scylla**:  ```cqlsh> DROP KEYSPACE catalog ;```

