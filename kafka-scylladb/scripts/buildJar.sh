#!/bin/bash

mvn clean compile assembly:single
mv target/scylladb-kafka-1.0-SNAPSHOT-jar-with-dependencies.jar .
