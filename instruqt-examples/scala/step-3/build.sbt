import Dependencies._

ThisBuild / scalaVersion := "2.13.16"
ThisBuild / version := "0.1.0-SNAPSHOT"
ThisBuild / organization := "com.scylla.mms"

// Add Java 21 compatibility settings
ThisBuild / javacOptions ++= Seq("-source", "11", "-target", "11")
ThisBuild / javaOptions ++= Seq("--add-opens= 