General Info and Prerequisites
==============================

The following scripts performs the following:
- Create the schema (keyspace, table and secondary indexes)
- Emulate 10K sensors, each sensor emitting 2000 data points, while using prepared statements


**Pre-requisites**
- [python 2.7](https://www.python.org/download/releases/2.7/)
- Cassandra driver: ```pip install cassandra-driver```
- [Scylla cluster up and running](https://www.scylladb.com/download/)
- ```experimental: true``` enabled in ```scylla.yaml``` file (needed for secondary indexes in v2.1)


Instructions
============

**How to run**
1. Download the file
2. Run: ```python [file_name].py -c [scylla nodes IP, comma separated] &```
	- Example: ```python 1_insert_ts_direct_new.py -c 172.16.0.62,172.16.0.204,172.16.0.67 &```
3. If you need to emulate more sensors, just clone the script and change ```start_range1``` to the start of the next range.
