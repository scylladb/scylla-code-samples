# Real-time credit scoring application with Feast & ScyllaDB

This repository is based on [this](https://github.com/feast-dev/feast-aws-credit-scoring-tutorial) existing Feast sample application.

![scylla feast architecture](/docs/source/_static/img/scylla-feast.jpg)

This sample project is a real-time credit scoring application example that shows you how to set up Feast with ScyllaDB Cloud as an online store and parquet files as offline store.

## What is a feature store?
Feature store is a central data store to power operational machine learning models. They help you store transformed feature values in a scalable and performant database. Real-time inference requires features to be returned to applications with low latency at scale. This is where ScyllaDB can play a crucial role in your machine learning infrastructure.

[![](https://mermaid.ink/img/pako:eNptkLtuwzAMRX-F4NDJ_gEPBdq62bI0mWp7ICRaFqqHQckpgjj_XtVJOxTlxMe5xCUvqKJmbHB08VNNJBmObR-gxFN3FAppjOJZwwOQMcKGcik0ZRqgrh_hhr50B3V2jtpnqCEGZwNDylHIMAx3ZMPXHWc1QRaywQazLUqcV2i7ffHhfif_qUamvAjDiVXZnVZ4vYsSy-mvZte9Mbk6W89A85wGrNCzeLK6XHv5RnvME3vusSmpJvnosQ_XwtGS4-EcFDZZFq5wmYtPbi0ZIY_NSC6VLmtbbOxv79u-WOFM4T3GH-b6BaPtdAY?type=png)](https://mermaid.live/edit#pako:eNptkLtuwzAMRX-F4NDJ_gEPBdq62bI0mWp7ICRaFqqHQckpgjj_XtVJOxTlxMe5xCUvqKJmbHB08VNNJBmObR-gxFN3FAppjOJZwwOQMcKGcik0ZRqgrh_hhr50B3V2jtpnqCEGZwNDylHIMAx3ZMPXHWc1QRaywQazLUqcV2i7ffHhfif_qUamvAjDiVXZnVZ4vYsSy-mvZte9Mbk6W89A85wGrNCzeLK6XHv5RnvME3vusSmpJvnosQ_XwtGS4-EcFDZZFq5wmYtPbi0ZIY_NSC6VLmtbbOxv79u-WOFM4T3GH-b6BaPtdAY)


## Why should you consider ScyllaDB as feature store?
ScyllaDB is a real-time NoSQL database that is best suited for feature store use cases where you require low latency (e.g. model serving), high throughout (e.g. training) and need peta-byte scalability.

* **Low-latency**: ScyllaDB can provide <1 ms P99 latency. For real-time machine learning apps, an online feature store is required to meet strict latency requirements. ScyllaDB is an excellent choice for an online store (Read how [Medium is using ScyllaDB](https://medium.engineering/scylladb-implementation-lists-in-mediums-feature-store-part-2-905299c89392) as a feature store.)
* **High-throughput**: Training requires querying huge amounts of data and processing large datasets with possibly millions of operations per second - something that ScyllaDB excels at.
* **Large-scale**: ScyllaDB can handle petabytes of data while still keeping latency low and predictable.
* **High availability**: ScyllaDB is a highly available database. With its distributed architecture, ScyllaDB keeps your feature store database always up and running.
* **Easy to migration**: ScyllaDB is compatible with DynamoDB API and Cassandra which means it's simple to migrate over from legacy solutions.
* **Integration with Feast**: ScyllaDB integrates with the popular open-source feature store framework, Feast.



## Requirements

* Python 3
* [ScyllaDB Cloud account](https://cloud.scylladb.com/)

## Get started

Clone the repository:
```
git clone https://github.com/zseta/scylladb-feast
cd scylladb-feast
```

Project details:
* The primary training dataset is in `loan_table.parquet`. This file contains historic loan data with accompanying features. The dataset also contains a target variable, namely whether a user has defaulted on their loan.
* Feast is used during training to enrich the loan table with `zipcode` and `credit history` features from other parquet files.
* Feast is also used to serve the latest `zipcode` and `credit history` features for online credit scoring using ScyllaDB Cloud.

In this tutorial, you'll do the following steps:
1. Create a new ScyllaDB Cloud cluster
1. Create a new keyspace for the feature store
1. Install dependencies and configure Feast
1. Deploy and test the feature store

## Create ScyllaDB Cloud cluster
Go to [ScyllaDB Cloud](https://cloud.scylladb.com/) and create a new cluster (either "Free Tial" or "Dedicated VM"). You can use the smallest available machine for this sample app (`t3.micro`)
![choose machine type](/docs/source/_static/img/choose-machine.png)


## Create new keyspace
Install CQLSH command line tool and connect to the ScyllaDB cluster:
```
pip install cqlsh
cqlsh <SCYLLA-CLOUD-HOST> -u scylla -p <PASSWORD>
```

You can get the host address, username, and password from your ScyllaDB Cloud dashboard:
![scylla connect](/docs/source/_static/img/scylla-cloud-connect.png)

Create a new keyspace called `feast` in ScyllaDB (this keyspace will be populated by Feast):
```
CREATE KEYSPACE feast WITH replication = {'class': 'NetworkTopologyStrategy', 'replication_factor': '3'} ;
```

## Install dependencies and configure Feast

Create a new Python environment and install dependencies:
```
virtualenv env && source env/bin/activate
pip install -r requirements.txt
```

Next, configure ScyllaDB Cloud as the online store for Feast. 

> [!TIP]
> ScyllaDB is compatible with Apache Cassandra so you can use the Feast Cassandra connector with ScyllaDB

Open the feature_store.yaml file and add the host addresses, username (`scylla`), and password for ScyllaDB: 

```yaml
project: repo
# By default, the registry is a file (but can be turned into a more scalable SQL-backed registry)
registry: data/registry.db
# The provider primarily specifies default offline / online stores & storing the registry in a given cloud
provider: local
online_store:
    type: cassandra
    hosts:
        - x.x.x.x
        - x.x.x.x
        - x.x.x.x
    username: scylla
    password: pass
    keyspace: feast
entity_key_serialization_version: 2
```

You can get these values from the ScyllaDB Cloud dashboard.


## Deploy and test the feature store

Deploy the feature store by running `apply` from within the `feature_repo/` folder
```
cd feature_repo/
feast apply


Deploying infrastructure for credit_history
Deploying infrastructure for zipcode_features
```

This commmand also generates a `registry.db` file in your `data/` folder containing Feast configuration information.

Next, load features into the online store using the `materialize-incremental` command. This command loads the
latest feature values from a data source (parquet files, in our case) into the online store (ScyllaDB).

```
CURRENT_TIME=$(date -u +"%Y-%m-%dT%H:%M:%S")
feast materialize-incremental $CURRENT_TIME
```

The loading process starts:
```
 35%|███████████████████▋                                     | 9965/28844 [01:20<02:39, 118.37it/s]
```

When it's completed, train the model using `run.py` (in the root folder of the repository)
```
cd ..
python run.py
```

The script returns the result of a single loan application:
```
Loan rejected!
```

You can also run `feast ui` to explore your features:
```
feast ui
```

Open http://0.0.0.0:8888
![feast ui](/docs/source/_static/img/feast-ui.png)

## Interactive demo
Run the Streamlit app locally:
```
streamlit run app.py
```

Go to http://localhost:8501

![streamlit app](/docs/source/_static/img/streamlit_app.png)

You can modify the variables on the left sidebar then the app will automatically run the prediction using the model.
