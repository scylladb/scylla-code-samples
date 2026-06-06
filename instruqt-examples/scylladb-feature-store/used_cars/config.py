import os

# ScyllaDB Configuration - Use environment variables with fallbacks
SCYLLA_HOSTS = os.environ.get('SCYLLA_HOSTS', 'node1').split(',')
SCYLLA_KEYSPACE = os.environ.get('SCYLLA_KEYSPACE', 'feature_store')
SCYLLA_USER = os.environ.get('SCYLLA_USER', 'scylla')
SCYLLA_PASS = os.environ.get('SCYLLA_PASS', '')
SCYLLA_DC = os.environ.get('SCYLLA_DC', 'datacenter1')

# Application Configuration
SCHEMA_FILE = 'schema.cql'
TABLE = 'car_features'
CSV_FOLDER = './data'