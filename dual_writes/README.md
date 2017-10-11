General Info and Prerequisites
==============================

This example will demonstrate how dual write data to two different clusters.

- create two cluster session
- generate random data with timestamp
- write that data to both clusters
- simulate write failure by randomly setting consistency level to quorum (which will fail on single node localhost clusters)
- report insert failure for either write

At a minimum you need a single Scylla server running on localhost.  


Instructions
============

Run `./dual_writes.py` 


--help 
===================

```
usage: dual_writes.py [-h] [-c1 C1] [-c2 C2] [-w RANDOM_WRITES]

optional arguments:
  -h, --help        show this help message and exit
  -c1 C1
  -c2 C2
  -w RANDOM_WRITES
```

Args:
  - -c1  Cluster 1 IP addresses, comma separated (i.e. 192.168.1.1,192.168.1.2,192.168.1.3)
  - -c2  Cluster 2 IP addresses, comma separated (i.e. 192.168.2.1,192.168.2.2,192.168.2.3)
  - -w   Number of random writes to perform.


Sample Output
=======================
```
~/dual_writes $ ./dual_writes.py 
[1, 1, [7, '6dff6b0c-dc19-40b6-90ef-15c05abb5b35', 1507751548592609]]
[1, 1, [523, '8383451d-e726-4f22-b612-f44596854ba3', 1507751548637472]]
[1, 0, [492, '565fa880-72ff-4398-a3dc-4ac01a6ba7ca', 1507751548640035]]
Write to cluster 2 failed
[1, 1, [497, '83479e8b-69cb-431f-ba23-f9ba3608b03b', 1507751548641846]]
[1, 1, [849, 'b0ace10a-7651-4bb9-ac6f-4badce5b114b', 1507751548643284]]
[1, 1, [491, 'ee6c8d79-38e1-4a15-aae8-8603c8e68362', 1507751548644673]]
[0, 0, [156, '8e7bb39a-019e-4914-b0cf-456a6b097297', 1507751548646173]]
Write to cluster 1 failed
Write to cluster 2 failed
[0, 1, [599, '93f6a1eb-c4dc-4f8b-9b71-e95068967c62', 1507751548648143]]
Write to cluster 1 failed
[1, 0, [491, '19cbbd6f-6775-467c-b938-2d8129285bae', 1507751548649671]]
Write to cluster 2 failed
[0, 1, [603, 'a3ec517a-3b82-4617-8e02-12d13d2ed901', 1507751548651293]]
Write to cluster 1 failed
```

