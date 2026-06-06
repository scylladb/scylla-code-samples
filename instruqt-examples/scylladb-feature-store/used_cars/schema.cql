CREATE KEYSPACE IF NOT EXISTS feature_store WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'replication_factor': 3
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
