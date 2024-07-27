General Info and Prerequisites
==============================

This sample shows how to work with time series data in ScyllaDB using the Scylla Python Driver.

The following scripts performs the following:
- Create the schema (keyspace, table and secondary indexes)
- Emulate 10K sensors, each sensor emitting 2000 data points, while using prepared statements


**Pre-requisites**
- [python 2.7, 3.5, 3.6, 3.7 or 3.8](https://www.python.org/download)
- [pip](https://pip.pypa.io/en/stable/installing/)
- [Scylla Python Driver](https://python-driver.docs.scylladb.com/stable/installation.html)
- [ScyllaDB Node or Cluster up and running](https://www.scylladb.com/download/)

Instructions
============

First, spin a fresh ScyllaDB Cluster:

```sh
docker run --name nodeX --publish '9042:9042' --rm -d scylladb/scylla:6.0.1 --overprovisioned 1 --smp 1
```

Then, make sure to install our Driver into your Python environment: 

```shell
pip install scylla-driver
```

and run the script:

```shell
python timeseries.py -c localhost &
```

> [!TIP]
> If you're running a cluster instead a single ScyllaDB node, you can add other node addresses splitted by comma:  "-c node1,node2,node3".


You can learn more about drivers at [ScyllaDB University: S210 Using Drivers](https://university.scylladb.com/courses/using-scylla-drivers/)