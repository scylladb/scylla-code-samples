package com.scylladb.kafka;

import com.scylladb.data.SP_DataParser;
import com.scylladb.scylla.ScyllaManager;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.Arrays;
import java.util.Properties;

// Kafka consumer thread
public class Consumer extends Thread {
    // Id for this consumer thread.
    private int consumerId;
    // Kafka configuration parameters.
    private Properties kafkaConfigProperties = new Properties();
    // Consumer.
    private KafkaConsumer<String, String> consumer;
    // Topic to subscribe to.
    private String topic;
    // Kafka configuration parameters.
    private Properties scyllaConfigProperties = new Properties();

    public Consumer(int consumerId, String kafkaConfigFile, String topic, String groupId,
                    String scyllaConfigFile) throws IOException {
        this.consumerId = consumerId;
        kafkaConfigProperties.load(new FileInputStream(kafkaConfigFile));
        kafkaConfigProperties.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
        this.topic = topic;
        consumer = new KafkaConsumer<String, String>(kafkaConfigProperties);
        scyllaConfigProperties.load(new FileInputStream(scyllaConfigFile));
    }

    public void run() {
        // subscribe to topic.
        consumer.subscribe(Arrays.asList(topic));
        // Write to Scylla what we  have consumed.
        // ScyllaManager is singleton for every consumer thread.
        ScyllaManager manager = ScyllaManager.getInstance(scyllaConfigProperties);
        try {
            while (true) {
                // poll Kafka queue every 100 millis.
                ConsumerRecords<String, String> records = consumer.poll(100);
                for (ConsumerRecord<String, String> record : records) {
                    manager.insert(SP_DataParser.decode(record.value()));
                    System.out.println("Inserting message from topic "
                            + this.topic
                            + " in "
                            + scyllaConfigProperties.getProperty("scylla.keyspace")
                            + "." + scyllaConfigProperties.getProperty("scylla.table"));
                }
            }
        } catch (Exception ex) {
            System.out.println("Exception caught " + ex.getMessage());
        } finally {
            consumer.close();
            System.out.println("After closing KafkaConsumer");
        }
    }

    /**
     * Trigger an exeption in the consumer thread that will stop it.
     */
    public void shutDown() {
        this.consumer.wakeup();
    }

}
