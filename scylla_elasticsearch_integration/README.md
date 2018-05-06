General Info and Prerequisites
==============================

The following example creates an apparel catalog stored on Scylla, and searchable using Elasticsearch (ES).      
We will be using two python scripts to demonstrate the integration of Scylla with Elasticsearch.
1. Dual writes using the “insert_data” script for data ingestion, in our case an apparel catalog csv file.
2.  Textual search using the “query_data” script, a 2-hop query that will retrieve the unique product_id (SKU) from Elasticsearch and then use the SKU to retrieve all the other product attributes from Scylla.


**Prerequisites**
- [python installed](https://www.python.org/download/releases/2.7/)
- [pip installed](https://packaging.python.org/guides/installing-using-linux-tools/)
- [Java 8 installed](http://openjdk.java.net/install/)
- [Scylla cluster up and running](https://www.scylladb.com/download/)
- An instance for Elasticsearch installation and python scripts (can be separate instances)



Instructions
============

**Procedure**
1. Install the python drivers on the node to be used for the scripts
```
$ sudo pip install cassandra-driver
$ sudo pip install elasticsearch
```

2. Install [Elasticsearch](https://www.elastic.co/guide/en/beats/libbeat/current/elasticsearch-installation.html)
```
$ sudo apt-get update
$ curl -L -O https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.2.3.deb 
$ sudo dpkg -i elasticsearch-6.2.3.deb
```

3. Start Elasticsearch, verify status and health state
```
$ sudo /etc/init.d/elasticsearch start
[ ok ] Starting elasticsearch (via systemctl): elasticsearch.service.
```
```
curl http://127.0.0.1:9200/_cluster/health?pretty 
{
  "cluster_name" : "elasticsearch",
  "status" : "green",
  "timed_out" : false,
  "number_of_nodes" : 1,
  "number_of_data_nodes" : 1,
  "active_primary_shards" : 0,
  "active_shards" : 0,
  "relocating_shards" : 0,
  "initializing_shards" : 0,
  "unassigned_shards" : 0,
  "delayed_unassigned_shards" : 0,
  "number_of_pending_tasks" : 0,
  "number_of_in_flight_fetch" : 0,
  "task_max_waiting_in_queue_millis" : 0,
  "active_shards_percent_as_number" : 100.0
}
```

4. Copy the files to the location from which you will run them, and make them executable
	- catalog.csv (the SKU is the unique product_id, made of other product attributes initials)
	- insert_data_into_scylla+elastic.py
	- query_data_from_scylla+elastic.py

5. Run the *“insert_data”* script. The script will perform the following:
	- Create the Schema on Scylla
	- Create the Elasticsearch index
	- Dual write: insert the catalog items (csv file) to both DBs (using prepared statement for Scylla)

Use the ```-s | -e``` flags to insert a comma-separated list of IPs for the Scylla and Elasticsearch (ES) nodes.
If you are running Elasticsearch (ES) on the same node as the python scripts, no need to enter IP, default 127.0.0.1 will be used.

```
$ python insert_data_into_scylla+elastic.py -h
	usage: insert_data_into_scylla+elastic.py [-h] [-s SCYLLA_IP] [-e ES_IP]

	optional arguments:
	  -h, --help    show this help message and exit
	  -s SCYLLA_IP
	  -e ES_IP
```

6. Once the *“insert_data”* script completes, you will find 160 entries in both Scylla and Elasticsearch
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
```
cqlsh> SELECT COUNT (*) FROM catalog.apparel ;

 count
-------
   160

(1 rows)
```

7. Run the *“query_data”* script. The script will perform the following:
	- Textual search in Elasticsearch using single / multiple filter/s, or no filter (match_all)
	- Use the Elasticsearch results to query Scylla (using prepared statement)

Use the ```-s | -e``` flags to insert a comma-separated list of IPs for the Scylla and Elasticsearch nodes.
If you are running Elasticsearch on the same node as the python scripts, no need to enter IP, default 127.0.0.1 will be used.

Use the ```-n``` flag to select the query type, the optional values are:
- **single**: using a single filter (by group) to query for *“pants”*
- **multiple (default)**: using multiple filters (by color and sub_group) to query for *"white softshell"*
- **none**: query without any filter = *match_all*

**Note:** Elasticsearch returns only the 1st 10 results by default. To overcome this we set the size limit to 1000 results. For large result we recommend using pagination (read more here: [elasticsearch-py helpers](http://elasticsearch-py.readthedocs.io/en/master/helpers.html?highlight=scroll)).

```
$ python query_data_from_scylla+elastic.py -h
usage: query_data_from_scylla+elastic.py [-h] [-s SCYLLA_IP] [-e ES_IP] [-n NUM_FILTERS]

optional arguments:
  -h, --help      show this help message and exit
  -s SCYLLA_IP
  -e ES_IP
  -n NUM_FILTERS
```

8. To delete Elasticsearch index and the keyspace in Scylla run the following commands
	- **Elasticsearch**:  ```$ curl -X DELETE "127.0.0.1:9200/catalog"```
	- **Scylla**:  ```cqlsh> DROP KEYSPACE catalog ;```

