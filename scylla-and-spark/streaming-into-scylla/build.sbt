// give the user a nice default project!

lazy val root = (project in file(".")).

  settings(
    inThisBuild(List(
      organization := "com.scylladb",
      scalaVersion := "2.11.11"
    )),
    name := "streaming-into-scylla",
    version := "0.0.1",

    javacOptions ++= Seq("-source", "1.8", "-target", "1.8"),
    javaOptions ++= Seq("-Xms512M", "-Xmx2048M", "-XX:MaxPermSize=2048M", "-XX:+CMSClassUnloadingEnabled"),
    scalacOptions ++= Seq("-deprecation", "-unchecked", "-Ypartial-unification"),
    parallelExecution in Test := false,
    fork := true,

    scalafmtOnCompile := true,

    libraryDependencies ++= Seq(
      "org.apache.spark" %% "spark-streaming" % "2.2.0" % "provided",
      "org.apache.spark" %% "spark-sql" % "2.2.0" % "provided",
      "org.apache.spark" %% "spark-sql-kafka-0-10" % "2.2.0",

      "com.typesafe.akka" %% "akka-stream" % "2.5.16",
      "com.typesafe.akka" %% "akka-http" % "10.1.4",

      "io.circe" %% "circe-core" % "0.9.3",
      "io.circe" %% "circe-generic" % "0.9.3",
      "io.circe" %% "circe-parser" % "0.9.3",

      "de.heikoseeberger" %% "akka-http-circe" % "1.21.0",

      "com.datastax.spark" %% "spark-cassandra-connector" % "2.3.0",
      "commons-configuration" % "commons-configuration" % "1.10",

      "org.scalatest" %% "scalatest" % "3.0.1" % "test",
      "org.scalacheck" %% "scalacheck" % "1.13.4" % "test"
    ),

    // uses compile classpath for the run task, including "provided" jar (cf http://stackoverflow.com/a/21803413/3827)
    run in Compile := Defaults.runTask(fullClasspath in Compile, mainClass in (Compile, run), runner in (Compile, run)).evaluated,

    (assembly / assemblyMergeStrategy ):= {
      case PathList("org", "apache", "spark", "unused", "UnusedStubClass.class") => MergeStrategy.first
      case x => (assembly / assemblyMergeStrategy).value(x)
    },

    pomIncludeRepository := { x => false },

   resolvers ++= Seq(
      "sonatype-releases" at "https://oss.sonatype.org/content/repositories/releases/",
      "Typesafe repository" at "http://repo.typesafe.com/typesafe/releases/",
      "Second Typesafe repo" at "http://repo.typesafe.com/typesafe/maven-releases/",
      Resolver.sonatypeRepo("public")
    ),

    pomIncludeRepository := { x => false },

    // publish settings
    publishTo := {
      val nexus = "https://oss.sonatype.org/"
      if (isSnapshot.value)
        Some("snapshots" at nexus + "content/repositories/snapshots")
      else
        Some("releases"  at nexus + "service/local/staging/deploy/maven2")
    }
  )
