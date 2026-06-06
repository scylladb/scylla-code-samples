var cassandra = require('cassandra-driver');

const client = new cassandra.Client({
    contactPoints: [
        'localhost:9042',  // node1
        'localhost:9043',  // node2
        'localhost:9044'   // node3
    ],
    localDataCenter: 'datacenter1',  
    keyspace: 'catalog',
});

console.log('Connecting to Scylla cluster');
client.connect()
    .then(() => {
        console.log('Successfully connected to the ScyllaDB databasebase!');
        return client.shutdown();
    })
    .catch((err) => {
        console.error('Failed to connect to ScyllaDB database:', err.message);
    }); 