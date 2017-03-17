name := "rita-analyzer"

version := "1.0"

scalaVersion := "2.11.8"

val sparkVersion =  "2.1.0"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion % "provided" exclude("com.google.guava", "guava"),
  "org.apache.spark" %% "spark-sql" % sparkVersion % "provided" exclude("com.google.guava", "guava"),
  "org.apache.spark" %% "spark-catalyst" % sparkVersion % "provided" exclude("com.google.guava", "guava"),
  "org.apache.spark" %% "spark-hive" % sparkVersion % "provided" exclude("com.google.guava", "guava"),

  "com.datastax.spark" %% "spark-cassandra-connector" % "2.0.0-M3" exclude("com.google.guava", "guava") withSources() withJavadoc()
)

