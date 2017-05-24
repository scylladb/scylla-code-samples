package com.scylladb.kafka;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.Date;
import java.util.List;
import java.util.Properties;

// Kafka producer.
public class Producer {
    // Kafka properties.
    private Properties configProperties = new Properties();
    // Producer.
    private KafkaProducer producer;

    /**
     * @param configFilePath: Kafka configuration file path.
     * @throws IOException
     */
    public Producer(String configFilePath) throws IOException {
        configProperties.load(new FileInputStream(configFilePath));
        producer = new KafkaProducer<String, String>(configProperties);
    }

    /**
     * Push a list of messages to our Kafka queue.
     *
     * @param msgs
     */
    public void send(List<KafkaMessage> msgs) {
        for (KafkaMessage msg : msgs) {
            System.out.println("Sending message to topic '" + msg.topic + "' at " + new Date());
            ProducerRecord<String, String> rec = new ProducerRecord<String, String>(msg.topic, msg.message);
            producer.send(rec);
        }
        producer.flush();
    }

    /**
     * Close the producer.
     */
    public void close() {
        producer.close();
    }

    // Simple placeholder class for topic and message.
    public static class KafkaMessage {
        private String topic;
        private String message;

        public KafkaMessage(String topic, String message) {
            this.topic = topic;
            this.message = message;
        }
    }
}
