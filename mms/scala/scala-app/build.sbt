import Dependencies._

ThisBuild / scalaVersion := "2.13.2"
ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / organization := "com.scylla.mms"

lazy val root = (project in file("."))
  .settings(
    name := "mms-scala-app",
    mainClass := Some("com.scylla.mms.App"),
    libraryDependencies ++= Seq(
      phantom,
      scalaReflect,
      scalaTest % Test
    ),
    assembly / assemblyMergeStrategy := {
      case PathList("META-INF", "io.netty.versions.properties") =>
        MergeStrategy.first
      case x =>
        val oldStrategy = (assemblyMergeStrategy in assembly).value
        oldStrategy(x)
    }
  )
