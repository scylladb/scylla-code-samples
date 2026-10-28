# Apache Kafka + Kafka Connect + MQTT Connector + Sensor Data

This demo shows an Internet of Things (IoT) integration example using Apache Kafka + Kafka Connect + MQTT Connector + Sensor Data.

This project does not include any source code as Kafka Connect allows integration with data sources and sinks just with configuration. 


### Requirements
- Java 8
- [Confluent Platform 5.0+](https://www.confluent.io/download/) (Confluent Enterprise if you want to use the Confluent MQTT Proxy, Confluent Open Source if you just want to run the KSQL UDF and send data via kafkacat instead of MQTT)
- MQTT Client and Broker (this demo uses [Mosquitto](https://mosquitto.org/download/))
- [Confluent MQTT Connector](https://www.confluent.io/connector/kafka-connect-mqtt/) (a Kafka Connect based connector to send and receive MQTT messages) - Very easy installation via Confluent Hub, just one command:

                confluent-hub install confluentinc/kafka-connect-mqtt:1.0.0-preview
- Optional: [MQTT.fx](https://mqttfx.jensd.de/) (a nice, simple UI to test MQTT pub/sub; not required - just makes life more comfortable)

The code is developed and tested on Mac.






