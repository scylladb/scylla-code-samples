This demo shows how to run a simple Spark 3.5 job to enrich a simple ScyllaDB table

Prerequisites:
---------------
Read and run below carefully, any of steps is skipped or broken, the whole app will error out with weird messages ;-)
Below works well in Fedora 34, replace the dnf/yum commands with their appropriate apt alternative for debian systems

Make sure you have docker installed.
https://docs.docker.com/engine/install/

start a scylla container:
```
./start-scylla-container.sh
```

Now you should have ScyllaDB 2026.2.1 listening on port 9044
verify using `docker ps`

Make sure you have a JDK 17 installed (Spark 3.5 supports Java 8, 11 and 17).
The *.sh scripts use your JAVA_HOME if it's set, and otherwise /usr/lib/jvm/java-17.

```
sudo dnf -y install java-17-openjdk-devel
```

Get Spark 3.5 from https://spark.apache.org/downloads.html (select Spark 3.5.x, package type "Pre-built for Apache Hadoop 3.3 and later"):

```
wget https://archive.apache.org/dist/spark/spark-3.5.5/spark-3.5.5-bin-hadoop3.tgz
```

unzip it locally and symlink spark3 dir to it, e.g.

```
tar xzvf spark-3.5.5-bin-hadoop3.tgz
ln -s spark-3.5.5-bin-hadoop3 spark3
```

Install cqlsh to connect to ScyllaDB on port 9044:

```
pip3 install cqlsh
```

Check if scylla container really runs:

```
cqlsh $HOSTNAME 9044
```

Make sure you have latest sbt:
https://www.scala-sbt.org/1.x/docs/Installing-sbt-on-Linux.html


Running the demo:
-----------------

Populate the DB:

```
cqlsh $HOSTNAME 9044 -f samplespark3.cql
```
(check extra commands for showing the contents after data load, note null values in "lettersinname")

Build the project:

```
java --version
```

should say OpenJDK 11 or 17
then build:

```
sbt assembly
```

Verify you have the jar built:
```
ls -la target/scala-2.12/spark3-scylla4-example-assembly-0.1.jar
```

Start spark3:

```
./start-spark3.sh
```

UI should be listening on $HOSTNAME:8080
(or any bigger free port, e.g. 8081)

Submit the app:

```
./submit_job_spark3.sh
```

Ideally close to the end before "SparkUI: Stopped Spark web UI" you will see:

`Accumulator: "Changed Row Count" is set to: 4`

And that means the first run was sucessfull and updated the rows without info.

If you go for second round, job will be smarter to not update stuff without null values for "lettersinname" column:

Accumulator: "Changed Row Count" is set to: 0

And that's it :-) 

Extra commands:
---------------

to trash the keyspace easily do:
```
cqlsh $HOSTNAME 9044 -e "drop keyspace myOwnKeyspace"
```

to show current rows:
```
cqlsh $HOSTNAME 9044 -e "select * from myOwnKeyspace.sparseTable"
```

If you want to run the commands from the app interactively, use Spark REPL:
```
./spark3-shell.sh
```

