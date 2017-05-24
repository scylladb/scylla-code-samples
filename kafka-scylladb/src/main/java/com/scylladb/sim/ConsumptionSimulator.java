package com.scylladb.sim;

import com.scylladb.kafka.Consumer;
import com.scylladb.scylla.ScyllaManager;

// Simulate consumption of topics from Kafka queue and storage in Scylla.
public class ConsumptionSimulator {
    public static void main(String[] args) throws Exception {
        if (args.length < 5)
            throw new Exception("Need to specify topic, Kafka config file, group id, number of consumers" +
                    "and Scylla config file");

        String topic = args[0];
        String kafkaConfigFile = args[1];
        String groupId = args[2];
        // This is only useful when scaling.
        int nConsumers = Integer.valueOf(args[3]);
        String scyllaConfigFile = args[4];

        // Start the specified number of consumer threads and subscribe them to a topic.
        // Also provide them with Scylla cluster connection parameters.
        for (int i = 0; i < nConsumers; i++) {
            System.out.println(i);
            Consumer kafkaConsumer = new Consumer(
                    i,
                    kafkaConfigFile,
                    topic,
                    groupId,
                    scyllaConfigFile);
            kafkaConsumer.start();
        }
        // Close the Scylla manager
        ScyllaManager.terminate();
    }
}
