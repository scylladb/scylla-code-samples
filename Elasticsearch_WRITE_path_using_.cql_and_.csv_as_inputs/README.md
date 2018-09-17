General Info and Prerequisites
==============================

The following script will use `.cql` schema file and `.csv` data file as inputs to create an index in Elasticsearch (ES) and insert the data.

- The ES index name will be created based on the `.csv` file name
- The index `_id` field (index partition key) is based on the `PRIMARY KEY` taken from `.cql` schema (simple/composite/compound).
- The index `_type` field will represent the partition key (PK), in case of a compund key it will use `-` to concatenate the column names.
- The script will print progress for every 1000 rows processed and total rows processed in its output.


**Prerequisites**
- [python installed](https://www.python.org/download/releases/2.7/)
- [pip installed](https://packaging.python.org/guides/installing-using-linux-tools/)
- [Java 8 installed](http://openjdk.java.net/install/)
- An instance for Elasticsearch installation and python scripts (can be separate instances)
- `.cql` schema file that contains the table schema
- `.csv` data file in the following name format: `<keyspace>.<table>.csv`
- The data file contains a header line with the column names



Instructions
============

**Procedure**

1. Install the python drivers on the node to be used for the script
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

4. Copy the python file to the location from which you will run it, and make it executable. Place your `.csv` and `.cql` files in an accessible location (can be same dir as the python script)


5. Run the script (see below usage, important details and examples)

- **Usage**
```
$ python ES_insert_data_per_schema.py -h
usage: ES_insert_data_per_schema.py [-h] [-e ES_IP] [-c CSV_FILE_NAME]
                                    [-s CQL_SCHEMA_FILE_NAME]
                                    [-i IGNORE_CQL_SCHEMA]

optional arguments:
  -h, --help            show this help message and exit
  -e ES_IP
  -c CSV_FILE_NAME
  -s CQL_SCHEMA_FILE_NAME
  -i IGNORE_CQL_SCHEMA
```

- **Important Details**
	- Use `-e` flag to insert a comma-separated list of IPs for Elasticsearch (ES) nodes. If ES is running locally, no need for this flag, default `127.0.0.1` will be used
	- `-i` ignore_cql_schema -> default: `True`. Meaning it will use the 1st column from the `.csv` for the index `_id` field. If you have a compound PK use `-i no` so not to ignore the `.cql` schema
	- `-c` csv_file_name -> requires full path to file. Needs to be in the format as described in the prerequisites
	- `-s` cql_schema_file name -> requires full path to file. Checking schema for compound PK, if did not find it checking for simple PK
	- If `.cql` not provided (but `.csv` was provided), will fall back to ignoring cql schema and use the 1st column from the `.csv` for the index `_id` field
	- If both `.cql` + `.csv` files are not provided, error is printed and script exists.


- **Output Example Using Compound PK**
```
ubuntu@ip-172-16-0-124:~/scylla_elastic$ python ES_insert_data_per_schema.py -c ./cp_prod.product_all.csv -s ./cp_prod_product_all.cql -i no

## Check schema (./cp_prod_product_all.cql) for compound primary key to be used as index id

## Did not find a compound primary key, checking for regular primary key to be used as index id

## Connecting to ES -> Creating 'cp_prod.product_all' index, if not exist

## Write csv file (./cp_prod.product_all.csv) content into Elasticsearch

## Update every 1000 rows proccesed ##
Rows processed: 1000
Rows processed: 2000
Rows processed: 3000
Rows processed: 4000
Rows processed: 5000
Rows processed: 6000
Rows processed: 7000
Rows processed: 8000
Rows processed: 9000

## After all inserts, refresh index (just in case)


### Total Rows Processed: 9715 ###

```


- **Print 1 doc from Index**
	- Note the `_index`, `_type` and `_id` fields.

```
$ curl -XGET 'http://127.0.0.1:9200/move.inventory_by_sku/_search?size=1&pretty'
{
  "took" : 1,
  "timed_out" : false,
  "_shards" : {
    "total" : 5,
    "successful" : 5,
    "skipped" : 0,
    "failed" : 0
  },
  "hits" : {
    "total" : 160,
    "max_score" : 1.0,
    "hits" : [
      {
        "_index" : "move.inventory_by_sku",
        "_type" : "by_sku-bin_case_id",
        "_id" : "gm-shr-uv-gy-s-m-gm",
        "_score" : 1.0,
        "_source" : {
          "promise_qty" : "15",
          "non_locate_reserved_qty" : "19",
          "lock_qty" : "21",
          "ecomm_ringfence_qty" : "24",
          "dropship_status" : "order",
          "intransit_qty" : "23",
          "receipt_qty" : "13",
          "pre_sell_qty" : "16",
          "crossdock_qty" : "26",
          "location_id" : "shr",
          "picking_qty" : "17",
          "sku" : "gm-shr-uv-gy-s-m",
          "ecomm_rf_restricted" : "yes",
          "expected_date" : "2018-11-09",
          "backorder_qty" : "29",
          "ringfence_qty" : "11",
          "inv_adj_qty" : "22",
          "available_qty" : "30",
          "bin_case_id" : "gm",
          "broker_qty" : "28",
          "newstore_qty" : "20",
          "checkdigit" : "digit9",
          "dropship_qty" : "25",
          "reserved_qty" : "12",
          "caselot_qty" : "27",
          "physical_qty" : "18",
          "rdq_qty" : "14",
          "suspend_qty" : "10",
          "to_be_picked_qty" : "9"
        }
      }
    ]
  }
}
```


6. To delete Elasticsearch index run the following commands
	- `$ curl -X DELETE "127.0.0.1:9200/<index_name>"`

