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

async function addMutant(first_name, last_name, address, picture_location) {
    console.log(`\nAdding ${first_name} ${last_name}...`);
    await client.execute(
        'INSERT INTO mutant_data (first_name, last_name, address, picture_location) VALUES (?, ?, ?, ?)',
        [first_name, last_name, address, picture_location]
    );
    console.log("Added.\n");
}

async function main() {
    try {
        await client.connect();
        await showMutantData();
        await addMutant('Peter', 'Parker', '1515 Main St', 'https://tinyurl.com/peterparker123');
        await showMutantData();
    } catch (err) {
        console.error('Error:', err.message);
    } finally {
        await client.shutdown();
    }
}

main(); 