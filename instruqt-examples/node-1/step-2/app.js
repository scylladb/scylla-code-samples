var cassandra = require('cassandra-driver');

const client = new cassandra.Client({
    contactPoints: [
        'localhost:9042',
        'localhost:9043',
        'localhost:9044'
    ],
    localDataCenter: 'datacenter1',
    keyspace: 'catalog',
});

async function showMutantData() {
    const result = await client.execute('SELECT * FROM mutant_data');
    console.log("Data that we have in the catalog".padStart(30, "="));
    result.rows.forEach(row => {
        console.log(row.first_name, row.last_name);
    });
}

async function main() {
    try {
        await client.connect();
        await showMutantData();
    } catch (err) {
        console.error('Error:', err.message);
    } finally {
        await client.shutdown();
    }
}

main(); 