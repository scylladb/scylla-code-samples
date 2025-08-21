# Used car feature store with ScyllaDB

This repository contains training material to build a simplified feature store and real-time ML application
with ScyllaDB. The example app you'll build predicts used car prices based on the car's features.

## Create a ScyllaDB cluster

In production, a ScyllaDB cluster should include at least three nodes. In this example, you'll start with a single-node setup to keep things simple.


Start up a ScyllaDB node:
```run
docker run --name node1 --network scylla -p "9042:9042" -d scylladb/scylla-enterprise:2024.2 \
  --overprovisioned 1 \
  --smp 1
```

Check the status of your node:

```run
docker exec -it node1 nodetool status
```

The response you get back should be UN (Up and Normal). If it is not then wait a few seconds and try again as the node is not ready yet.
You should see something that looks like this:

```
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens       Owns    Host ID                               Rack
UN  172.17.0.2  204 KB     256          ?       b26ab7f8-17ee-4e51-b28a-523697d16a60  rack1
```

---

## Create a feature store keyspace and tables
In this part, you'll create a new keyspace and a new table.

Use cqlsh to interact with ScyllaDB:
```bash
docker exec -it node1 cqlsh
```

Create a keyspace called `feature_store`:
```sql
CREATE KEYSPACE feature_store
WITH REPLICATION = {
  'class' : 'NetworkTopologyStrategy',
  'replication_factor' : 1
};
```

With this CQL command, you set the following replication strategy:
* `NetworkTopologyStrategy`: A production ready replication strategy that allows to set the replication factor independently for each data-center
* `replication_factor:`: The number of nodes that will store the same data. In production you'd set this to 3 or higher, to ensure that if one node becomes unavailable, you can still query your data using another node.

Activate the newly created keyspace:
```run
use feature_store;
```

Next, create a table `used_cars` with the following columns: model, year, price, fuel_type, brand:
```sql
CREATE TABLE used_cars (
    car_id UUID,
    model TEXT,
    year INT,
		price FLOAT,
		brand TEXT,
    PRIMARY KEY (car_id)
);
```

You can confirm that the table has been created by using the following CQL command:
```sql
DESC SCHEMA;
```

You can notice, that the table definiton has `car_id` as the PARTITION KEY. This allows efficient queries by the `car_id` column.

---

## Partition key, filtering
Insert two rows into the newly created table:
```sql
INSERT INTO used_cars(car_id, model, year, price, brand)
  VALUES (70f6d200-e9fb-4765-af05-f5ef668e82ee, 'A6', 2022, 43950, 'Audi');
INSERT INTO used_cars(car_id, model, year, price, brand)
  VALUES (9a0807eb-05df-47dc-9081-095f7881b470, 'Q5', 2024, 45300, 'Audi');
```

Now, read the table:
```sql
SELECT * FROM used_cars;
```

Query the table and add a `WHERE` clause:
```sql
SELECT * FROM used_cars WHERE car_id = 70f6d200-e9fb-4765-af05-f5ef668e82ee;
```
This query is using the `car_id` column in the `WHERE` clause. This query is efficient and scalable because `car_id` is a PARTITION KEY.

Let's see what happens if you query by a non-PK column, `model`:
```sql
SELECT * FROM used_cars WHERE model = 'Q5';

```
You see an error message: `InvalidRequest: Error from server: code=2200 [Invalid query] message="Cannot execute this query as it might involve data filtering and thus may have unpredictable performance. If you want to execute this query despite the performance unpredictability, use ALLOW FILTERING"`.

What this means is that you tried to query by a non-PK column which would require a table scan and have unpredictable performance.

If you are willing to run a table scan, you can still execute the query using the `ALLOW FILTERING` extension:
```sql
SELECT * FROM used_cars WHERE model = 'Q5' ALLOW FILTERING;

```

What happens if you try to `INSERT` a new product with the same ID but different price?
```sql
INSERT INTO used_cars(car_id, model, year, price, brand)
  VALUES (70f6d200-e9fb-4765-af05-f5ef668e82ee, 'A6', 2022, 39000, 'Audi');
```

```sql
SELECT * FROM used_cars WHERE car_id = 70f6d200-e9fb-4765-af05-f5ef668e82ee;
```
In this case, because the car_id already exists in the table, ScyllaDB will perform `UPDATE` instead of inserting a new row (executing an `UPSERT`, in other words).

---

## Clustering key
Now, let's see how clustering keys help you access your data.

Create a new table, called `car_features`:
```sql
CREATE TABLE car_features (
  car_id uuid,
  feature_name text,
  feature_value text,
  PRIMARY KEY (car_id, feature_name)
);
```

Insert some sample data:
```sql
INSERT INTO car_features(car_id, feature_name, feature_value)
  VALUES (8fb321c6-8ee0-4cd8-8568-3f149b7c298c, 'brand', 'Audi');
INSERT INTO car_features(car_id, feature_name, feature_value)
  VALUES (8fb321c6-8ee0-4cd8-8568-3f149b7c298c, 'model', 'A1');
INSERT INTO car_features(car_id, feature_name, feature_value)
  VALUES (8fb321c6-8ee0-4cd8-8568-3f149b7c298c, 'fuel_type', 'Diesel');
INSERT INTO car_features(car_id, feature_name, feature_value)
  VALUES (8fb321c6-8ee0-4cd8-8568-3f149b7c298c, 'price', '14950');
```

This table contains features of used cars. Let's breakdown the PRIMARY KEY:
* `car_id`: PARTITION KEY - allows efficient queries using the `car_id` column
* `feature_name`: CLUSTERING KEY - allows efficient queries using the `car_id` AND the `feature_name`  columns

Query by `car_id` to fetch all the features for one car:
```sql
SELECT * FROM feature_store.car_features WHERE car_id = 8fb321c6-8ee0-4cd8-8568-3f149b7c298c;
```

By adding a CLUSTERING KEY, you can query one specific feature value, e.g. `model`:
```sql
SELECT * FROM car_features WHERE car_id = 8fb321c6-8ee0-4cd8-8568-3f149b7c298c AND feature_name = 'model';
```

Close cqlsh:
```sql
exit
```

Real-time machine learning app example
===
In this part, you'll set up a simplified machine learning app that predicts used car prices based on user input and a pre-trained model.

Connect to your ScyllaDB cluster using cqlsh and create the schema:
```bash
docker exec -it node1 cqlsh
```

```sql
CREATE KEYSPACE IF NOT EXISTS feature_store WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'replication_factor': 1
};

CREATE TABLE IF NOT EXISTS feature_store.car_features (
  car_id uuid,
  feature_name text,
  feature_value text,
  PRIMARY KEY (car_id, feature_name)
);

CREATE TABLE IF NOT EXISTS feature_store.raw_car_features (
    car_id UUID,
    brand TEXT,
    model TEXT,
    year INT,
    transmission TEXT,
    fuel_type TEXT,
    mpg FLOAT,
    engine_size FLOAT,
    mileage INT,
    tax FLOAT,
    PRIMARY KEY (car_id)
);
```

Exit cqlsh:
```sql
exit
```

---

## Test the app

Create a new virtual environment in the app's folder:
```bash
cd labs/used-cars-feature-store/
virtualenv env --python=python3.11 && source env/bin/activate
```

Install Python requirements (scikit-learn, scylla-driver, streamlit):
```bash
pip install scikit-learn scylla-driver streamlit
```

Use the `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' node1` command to get the ScyllaDB HOST address.
```bash
NODE1=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' node1)
echo $NODE1
```

Find the  `config.py` file:
```python
SCYLLA_HOSTS = ["172.18.0.4"]
SCYLLA_KEYSPACE = 'feature_store'
SCYLLA_USER = 'scylla'
SCYLLA_PASS = ''
SCYLLA_DC = 'dc1'
```

Make sure the `HOST` value contains the output of:
```bash
echo $NODE1
```
If it doesn't, fix it.


Run streamlit:
```bash
streamlit run app/app.py
```

Visit APP UI: http://localhost:8501

Hit `CTRL + C` to stop the server.