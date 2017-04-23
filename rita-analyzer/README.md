# How-to run Scylla on Spark: Analyzing average arrival/departure delays of the flights and their cancellations during a year within Airlines Transportation Data.
In the example we will demonstrate how to use Spark Scala API with ScyllaDB to get the data from public dataset  RITA  regarding the average arrival/departure delays of the flights and their cancellations during a year.
We will describe below the following cases:
- Top 3 destinations with highest average arrival delay
- Top 3 origins with highest average departure delay
- Top 3 carriers with highest average departure and arrival delay
- Top 3 carriers with highest flight cancellation

## Prepare an application
To prepare the data execute the following command in a terminal:
```
cd ~/Downloads
wget http://stat-computing.org/dataexpo/2009/2008.csv.bz2
mv 2008.csv.bz2 /tmp
bzip2 -d /tmp/2008.csv.bz2
```

To prepare the application execute the following command in a terminal:
```
cd ~/
git clone https://github.com/scylladb/scylla-code-samples.git
cd scylla-code-samples/rita-analyzer
sbt assembly
```


The next step is load previously downloaded data from /tmp/2008.csv file to ScyllaDB by executing the following command in Spark directory:
```
./bin/spark-submit --properties-file /path/to/rita-analyzer/spark-scylla.conf --class Loader /path/to/rita-analyzer/target/scala-2.11/rita-analyzer-assembly-1.0.jar
```

To run the application execute the following command in Spark directory in terminal:
```
./bin/spark-submit --properties-file /path/to/rita-analyzer/spark-scylla.conf --class Extractor /path/to/rita-analyzer/target/scala-2.11/rita-analyzer-assembly-1.0.jar
```


## Libraries versions:
- Scala 2.11.8
- Spark 2.1.0
- Scylla 1.6
