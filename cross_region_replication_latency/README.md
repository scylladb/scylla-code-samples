General Info and Prerequisites
==============================

These scripts enables you to measure Scylla's cross DC/region replication latency on Cloud or on-prem deployments.

In this specific code example we are using a single writer in us-east (N. Virginia) to write a single partition using CL=LOCAL_ONE, which we then read from us-west (Oregon) using a single reader.

The write rate is ~5 partitions per second. We calculate the replication latency time on the reader’s end by subtracting the partition's insert time from the partition's now() time at the moment it is read. In both cases it's the server/DB timestamps.


**Prerequisites**
- [python installed](https://www.python.org/download/releases/2.7/)
- [pip installed](https://packaging.python.org/guides/installing-using-linux-tools/)
- [Multi-DC Scylla cluster on AWS](http://docs.scylladb.com/procedures/ec2_dc/) - Two DCs, one in us-east-1 and the second in us-west-2 (can be different regions/cloud vendor, require a minor change in the scripts)
- An instance in each region for the writer and the reader scripts
- Scylla nodes clock is synced using either ```ntp``` or [chrony](https://aws.amazon.com/blogs/aws/keeping-time-with-amazon-time-sync-service/)



Instructions
============

1. Install the python drivers on the loaders that will run the scripts
```
$ sudo pip install cassandra-driver
$ sudo pip install time_uuid
```

2. Copy the python scripts to the location from which you will run them

3. Create the following Schema on the Scylla cluster

```
CREATE KEYSPACE replicated WITH replication = {'class': 'NetworkTopologyStrategy', 'us-east': '3', 'us-west-2': '3'}  AND durable_writes = true;

CREATE TABLE replicated.test (
    id uuid PRIMARY KEY,
    desired_response_counter int,
    insertion_date timeuuid,
    some_data text
) WITH bloom_filter_fp_chance = 0.01
    AND caching = {'keys': 'ALL', 'rows_per_partition': 'ALL'}
    AND comment = ''
    AND compaction = {'class': 'SizeTieredCompactionStrategy'}
    AND compression = {'sstable_compression': 'org.apache.cassandra.io.compress.LZ4Compressor'}
    AND crc_check_chance = 1.0
    AND dclocal_read_repair_chance = 0.1
    AND default_time_to_live = 0
    AND gc_grace_seconds = 864000
    AND max_index_interval = 2048
    AND memtable_flush_period_in_ms = 0
    AND min_index_interval = 128
    AND read_repair_chance = 0.0
    AND speculative_retry = '99.0PERCENTILE';

CREATE TABLE replicated.test_count (
    id uuid PRIMARY KEY,
    response_counter counter
) WITH bloom_filter_fp_chance = 0.01
    AND caching = {'keys': 'ALL', 'rows_per_partition': 'ALL'}
    AND comment = ''
    AND compaction = {'class': 'SizeTieredCompactionStrategy'}
    AND compression = {'sstable_compression': 'org.apache.cassandra.io.compress.LZ4Compressor'}
    AND crc_check_chance = 1.0
    AND dclocal_read_repair_chance = 0.1
    AND default_time_to_live = 0
    AND gc_grace_seconds = 864000
    AND max_index_interval = 2048
    AND memtable_flush_period_in_ms = 0
    AND min_index_interval = 128
    AND read_repair_chance = 0.0
    AND speculative_retry = '99.0PERCENTILE';
```

4. Run both the writer and reader scripts together as the following:
	- ```python scylla-tester-writer.py [IP from us-east DC] [num of readers]```
	- ```python scylla-tester-reader_log.py [IP from us-west DC] output_file.csv [run duration in min.]```

5. The resutls are logged into a csv file and at the end of the run you will get the ```Max``` and the ```Avg``` latencies output in ms. 
```
Max Latency (ms): 272.00
Avg Latency (ms): 81.46
```
