
ThisBuild / version := "0.1"

lazy val root = (project in file("."))
  .settings(
    name := "spark-scylla-fullscan"
  )

inThisBuild(
  List(
    idePackagePrefix := Some("com.scylladb"),
    organization := "com.scylladb",
    scalaVersion := "2.13.14",
    scalacOptions ++= Seq("-release:8", "-deprecation", "-unchecked", "-feature"),
  )
)

ThisBuild / libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-core" % "3.5.5" % "provided",
      "org.apache.spark" %% "spark-sql" % "3.5.5" % "provided",

      "com.datastax.spark" %% "spark-cassandra-connector" % "3.5.1"
    )
