General Info and Prerequisites
==============================

This scripts emulates 200K sensors, each writing 2000 data points, while using prepared statements.


**Pre-requisites**
- [python 2.7](https://www.python.org/download/releases/2.7/)
- Cassandra driver: ```pip install cassandra-driver```
- [Scylla cluster up and running](https://www.scylladb.com/download/)


Instructions
============

**How to run**
1. Download the files
2. Run: ```python [file_name].py -c [scylla nodes IP, comma separated] &```
	- Example: ```python 1_insert_ts_direct_scylla_25K.py -c 172.16.0.62,172.16.0.204,172.16.0.67 &```
