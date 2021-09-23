This demo shows how to run a simple spark 3 job to enrich a simple scylla 4.4 table

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

Now you should have scylla 4.4.3 listening on port 9044
verify using `docker ps`

Make sure you have OpenJDK 11 installed in /usr/lib/jvm/java-11
If it's elsewhere, fix paths in *.sh scripts !!!

```
sudo dnf -y install java-11-openjdk-devel
```

Get Spark 3.1:
https://spark.apache.org/downloads.html

```
wget https://apache.miloslavbrada.cz/spark/spark-3.1.2/spark-3.1.2-bin-hadoop3.2.tgz
```

unzip it locally and symlink spark3 dir to it, e.g.

```
tar xzvf spark-3.1.2-bin-hadoop3.2.tgz
ln -s spark-3.1.2-bin-hadoop3.2 spark3
```

Get local cqlsh

```
sudo dnf -y install git

git clone https://github.com/scylladb/scylla-tools-java.git

```

Make sure you have python2 at least installed.
Check if scylla container really runs after checkout of above:

```
./scylla-tools-java/bin/cqlsh $HOSTNAME 9044
```

Make sure you have latest sbt:
https://www.scala-sbt.org/1.x/docs/Installing-sbt-on-Linux.html


Running the demo:
-----------------

Populate the DB:

```
./scylla-tools-java/bin/cqlsh $HOSTNAME 9044 -f samplespark3.cql
```
(check extra commands for showing the contents after data load, note null values in "lettersinname")

Build the project:

```
java --version
```

should say OpenJDK 11
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
./scylla-tools-java/bin/cqlsh $HOSTNAME 9044 -e "drop keyspace myOwnKeyspace"
```

to show current rows:
```
./scylla-tools-java/bin/cqlsh $HOSTNAME 9044 -e "select * from myOwnKeyspace.sparseTable"
```

If you want to run the commands from the app interactively, use Spark REPL:
```
./spark3-shell.sh
```

