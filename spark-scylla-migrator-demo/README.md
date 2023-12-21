This demo shows how to run a spark scylla migration job between cassandra and scylla

Prerequisites:
---------------
You need at least 4 cpus and 8G of memory to run this

Read and run below carefully, any of steps is skipped or broken, the whole app will error out with weird messages ;-)
Below works well in Fedora 34, replace the dnf/yum commands with their appropriate apt alternative for debian systems

Make sure you have docker installed.
https://docs.docker.com/engine/install/

start latest cassandra and scylla containers:
```
./start-containers.sh
```

Now you should have scylla listening on port 9044
and cassandra on port 9043
verify using `docker ps`

Note that it might take some time, until they really start listening (e.g. first gossip startup).
You can verify with one of bonus commands (select or some describe quuery).

Make sure you have OpenJDK 8 installed in /usr/lib/jvm/java-1.8.0
If it's elsewhere, fix paths in *.sh scripts !!!

For RPM based distros:
```
sudo dnf -y install java-1.8.0-openjdk-devel
```

For DEB based distros:
```
sudo apt install -y openjdk-8-jre-headless
sudo apt install -y openjdk-8-jdk-headless
```

Get Spark 2.4.8:
https://spark.apache.org/downloads.html

```
wget https://archive.apache.org/dist/spark/spark-2.4.8/spark-2.4.8-bin-hadoop2.7.tgz
```

unzip it locally and symlink spark dir to it, e.g.

```
tar xzvf spark-2.4.8-bin-hadoop2.7.tgz
ln -s spark-2.4.8-bin-hadoop2.7 spark
```

Get local cqlsh

For RPM based distros:
```
sudo dnf -y install git
```

For DB based distros:
```
sudo apt install -y git
```

```
git clone https://github.com/scylladb/scylla-tools-java.git

```

Make sure you have python2 at least installed.
Check if scylla container really runs after checkout of above:

```
./scylla-tools-java/bin/cqlsh $HOSTNAME 9044
```

Make sure you have latest sbt:
https://www.scala-sbt.org/1.x/docs/Installing-sbt-on-Linux.html

Clone the migrator repo:
```
git clone https://github.com/scylladb/scylla-migrator
```

Running the demo:
-----------------

Populate the source DB:

```
./scylla-tools-java/bin/cqlsh $HOSTNAME 9043 -f sample.cql
```
(check extra commands for showing the contents after data load, note null values in "lettersinname")

Prepare schema in target DB:
```
./scylla-tools-java/bin/cqlsh $HOSTNAME 9044 -f prepare_target.cql
```

Build the project:

```
java -version
```

should say OpenJDK 1.8
then build:

Redhat based:
```
cd scylla-migrator
export JAVA_HOME=/usr/lib/jvm/java-1.8.0/
export PATH=$JAVA_HOME/bin:$PATH
./build.sh
```

Debian based:
```
cd scylla-migrator
export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64/
export PATH=$JAVA_HOME/bin:$PATH
./build.sh
```


Verify you have the jar built:
```
cd ..
ls -la scylla-migrator/target/scala-2.11/scylla-migrator-assembly-0.0.1.jar
```

Verify in `spark-env` size of your spark cluster,
ev. adjust sizes or number of workers
Also, edit star-spark.sh to comment out the JAVA_HOME variable as it is hard set and should be in your environment now.

Start spark:

```
./start-spark.sh
```

UI should be listening on $HOSTNAME:8080
(or any bigger free port, e.g. 8081)

Make sure you validate the `config.yaml` and fix anything missing (or sync it
with https://github.com/scylladb/scylla-migrator/blob/master/config.yaml.example 
to avoid any configuration load errors from migrator)
Also, edit submit_job.sh to comment out the JAVA_HOME variable as it is hard set and should be in your environment now.
You will likely need to add the following row under both source and target in config.yaml:

```
  consistencyLevel: LOCAL_QUORUM

```

Submit the app:

```
./submit_job.sh
```

You will see at the end few of:
"Created a savepoint config at /tmp/savepoints/savepoint_1627646471.yaml due to final."

That yaml file can be used as input config to resume at certain point(all token ranges
that were processed will be skipped).


Extra commands:
---------------

to trash the keyspace in target in target easily do:
```
./scylla-tools-java/bin/cqlsh $HOSTNAME 9044 -e "drop keyspace mykeyspace"
```
don't forget to prepare schema in target again!


to show current rows in target:
```
./scylla-tools-java/bin/cqlsh $HOSTNAME 9044 -e "select * from mykeyspace.users"
```

To validate with spark, you can run:
```
./submit_job_validator.sh
```

To run with 4 executors check out:
```
./submit_job-4execs.sh
```

To run spark shell use:
```
./spark-shell.sh
```
or to use 2.5.2 connector:
```
./spark-shell25.sh
```

To use debugging for driver AND for (single) executor run:
(you can attach to respective ports easily from Idea after loading the project)
```
./submit_job-debug.sh
```
