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

async function deleteMutant(first_name, last_name) {
    console.log(`\nDeleting ${first_name} ${last_name}...`);
    await client.execute(
        'DELETE FROM mutant_data WHERE last_name = ? and first_name = ?',
        [last_name, first_name]
    );
    console.log("Deleted.\n");
}

async function main() {
    try {
        await client.connect();
        await showMutantData();
        await deleteMutant('Peter', 'Parker');
        await showMutantData();
    } catch (err) {
        console.error('Error:', err.message);
    } finally {
        await client.shutdown();
    }
}

main(); 