package com.scylladb.sim;

import com.scylladb.data.SP_DataParser;
import com.scylladb.kafka.Producer;

import java.util.ArrayList;


// Simulate the production of records to push to the Kafka queue.
public class ProductionSimulator {
    public static void main(String[] args) throws Exception {
        if (args.length < 2) throw new Exception("Need to specify config file and data file");
        String configFilePath = args[0];
        String dataFilePath = args[1];

        // Kafka producer.
        Producer kafkaProducer = new Producer(configFilePath);

        // Data parser.
        SP_DataParser parser = new SP_DataParser(dataFilePath);


        // Read our csv input data, extract topic, build Kafka message and push to queue.
        ArrayList<String> linesJson;

        while (!(linesJson = parser.read(30)).isEmpty()) {
            ArrayList<Producer.KafkaMessage> msgs = new ArrayList<>();
            for (String s : linesJson) {
                msgs.add(new Producer.KafkaMessage(parser.getKey(s, "symbol"), s));
            }
            kafkaProducer.send(msgs);

            // Sleep two seconds to simulate time delays between incoming of real quotes.
            Thread.sleep(2000);
        }

        // Close open streams.
        kafkaProducer.close();
        parser.close();
    }
}
