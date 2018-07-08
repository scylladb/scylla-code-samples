/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.scylla.movies;

import com.datastax.driver.core.Cluster;
import com.datastax.driver.core.Session;
import com.datastax.driver.mapping.Mapper;
import com.opencsv.CSVParser;
import org.apache.flink.api.common.functions.FilterFunction;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.api.java.tuple.Tuple2;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.connectors.cassandra.CassandraSink;
import org.apache.flink.streaming.connectors.cassandra.ClusterBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.net.InetSocketAddress;
import java.util.Arrays;
import java.util.List;


public class FilterMoviesStreamingJob {

	private static final Logger LOG = LoggerFactory.getLogger(FilterMoviesStreamingJob.class);

	public static void main(String[] args) throws Exception {
		final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

		DataStream<String> movieData = env.readTextFile("/home/ubuntu/flink-1.5.0/data/");
		DataStream<Tuple2<String,List<String>>> movies = movieData.map(new MapFunction<String, Tuple2<String, List<String>>>() {
			@Override
			public Tuple2<String, List<String>> map(String value) throws Exception {
				CSVParser parser = new CSVParser();
				List<String> cols = Arrays.asList(parser.parseLine(value));
				return new Tuple2<String, List<String>>(cols.get(1), Arrays.asList(cols.get(2).split("\\|")));
			}
		}).filter(new FilterFunction<Tuple2<String, List<String>>>() {
			@Override
			public boolean filter(Tuple2<String, List<String>> value) throws Exception {
				if (value.f1.stream().anyMatch(s -> s.contains("Action"))) {
					return true;
				}
				return false;
			}
		});

		// filteredMovies.writeAsText("output.txt");

		// Create Scylla schema
		ClusterBuilder builder = new ClusterBuilder() {
			@Override
			protected Cluster buildCluster(Cluster.Builder builder) {
				return builder.addContactPointsWithPorts(new InetSocketAddress("172.16.0.95", 9042)).build();
			}
		};

		Cluster cluster = null;
		Session session = null;

		final String CREATE_KEYSPACE = "CREATE KEYSPACE flink_example WITH replication= {'class':'SimpleStrategy', 'replication_factor':1};";
		final String CREATE_TABLE = "CREATE TABLE flink_example.movies (title text PRIMARY KEY, genres list<text>);";

		try{
			long start = System.nanoTime();
			long deadline = start + 30_000_000L;
			while (true) {
				try {
					cluster = builder.getCluster();
					session = cluster.connect();
					break;
				} catch (Exception e) {
					if (System.nanoTime() > deadline) {
						throw e;
					}
					try {
						Thread.sleep(500);
					} catch (InterruptedException ignored) {
					}
				}
			}
			LOG.debug("Connection established after {}ms.", System.currentTimeMillis() - start);

			session.execute(CREATE_KEYSPACE);
			session.execute(CREATE_TABLE);
		} catch (Exception e){
			closeCassandra(cluster, session);
		}

		// Send results to Scylla
		CassandraSink.addSink(movies)
		.setHost("172.16.0.95")
		.setQuery("INSERT INTO flink_example.movies (title,genres) VALUES (?,?);")
		.setMapperOptions(() -> new Mapper.Option[]{Mapper.Option.saveNullFields(true)})
		.build();

		// execute program
		env.execute("Flink Stream Java API Skeleton");
	
	}

	static void closeCassandra(Cluster cluster, Session session) {	
		if (session != null) {
			session.close();
		}

		if (cluster != null) {
			cluster.close();
		}
	}
}


