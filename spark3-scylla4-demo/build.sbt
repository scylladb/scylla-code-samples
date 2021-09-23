name := "spark3-scylla4-example"

version := "0.1"

scalaVersion := "2.12.14"

idePackagePrefix := Some("com.scylladb")

libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-core" % "3.1.2" % "provided",
      "org.apache.spark" %% "spark-sql" % "3.1.2" % "provided",

      "com.datastax.spark" %% "spark-cassandra-connector" % "3.1.0"
    )