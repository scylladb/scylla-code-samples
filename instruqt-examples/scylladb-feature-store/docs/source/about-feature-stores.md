# Why should you consider ScyllaDB as a feature store?

<iframe width="560" height="315" src="https://www.youtube.com/embed/s6zUbmVRyK0?si=_onaNvTGpTbjwjD3" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

ScyllaDB is a real-time NoSQL database that is best suited for feature store use cases where you require **low latency** (e.g. model serving), **high throughout** (e.g. training) and need peta-byte scalability.

Feature store is a central data store to power operational machine learning models. They help you store transformed feature values in a scalable and performant database. Real-time inference requires features to be returned to applications with low latency at scale. This is where ScyllaDB can play a crucial role in your machine learning infrastructure.

[![](https://mermaid.ink/img/pako:eNptkLtuwzAMRX-F4NDJ_gEPBdq62bI0mWp7ICRaFqqHQckpgjj_XtVJOxTlxMe5xCUvqKJmbHB08VNNJBmObR-gxFN3FAppjOJZwwOQMcKGcik0ZRqgrh_hhr50B3V2jtpnqCEGZwNDylHIMAx3ZMPXHWc1QRaywQazLUqcV2i7ffHhfif_qUamvAjDiVXZnVZ4vYsSy-mvZte9Mbk6W89A85wGrNCzeLK6XHv5RnvME3vusSmpJvnosQ_XwtGS4-EcFDZZFq5wmYtPbi0ZIY_NSC6VLmtbbOxv79u-WOFM4T3GH-b6BaPtdAY?type=png)](https://mermaid.live/edit#pako:eNptkLtuwzAMRX-F4NDJ_gEPBdq62bI0mWp7ICRaFqqHQckpgjj_XtVJOxTlxMe5xCUvqKJmbHB08VNNJBmObR-gxFN3FAppjOJZwwOQMcKGcik0ZRqgrh_hhr50B3V2jtpnqCEGZwNDylHIMAx3ZMPXHWc1QRaywQazLUqcV2i7ffHhfif_qUamvAjDiVXZnVZ4vYsSy-mvZte9Mbk6W89A85wGrNCzeLK6XHv5RnvME3vusSmpJvnosQ_XwtGS4-EcFDZZFq5wmYtPbi0ZIY_NSC6VLmtbbOxv79u-WOFM4T3GH-b6BaPtdAY)


What ScyllaDB brings to the table:
* **Low-latency**: ScyllaDB can provide <1 ms P99 latency. For real-time machine learning apps, an online feature store is required to meet strict latency requirements. ScyllaDB is an excellent choice for an online store (Read how [Medium is using ScyllaDB](https://medium.engineering/scylladb-implementation-lists-in-mediums-feature-store-part-2-905299c89392) as a feature store.)
* **High-throughput**: Training requires querying huge amounts of data and processing large datasets with possibly millions of operations per second - something that ScyllaDB excels at.
* **Large-scale**: ScyllaDB can handle petabytes of data while still keeping latency low and predictable.
* **High availability**: ScyllaDB is a highly available database. With its distributed architecture, ScyllaDB keeps your feature store database always up and running.
* **Easy to migration**: ScyllaDB is compatible with DynamoDB API and Cassandra which means it's simple to migrate over from legacy solutions.
* **Integration with Feast**: ScyllaDB integrates well with the popular open-source feature store framework, Feast. Example architecture with Feast and ScyllaDB:

![scylla feast architecture](/_static/img/scylla-feast.jpg)