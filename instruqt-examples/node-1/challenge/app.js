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

async function checkForMutant(first_name, last_name) {
    const result = await client.execute(
        'SELECT * FROM mutant_data WHERE first_name = ? and last_name = ?',
        [first_name, last_name]
    );
    return result.rowLength > 0;
}

// TODO: Implement this function!
async function addMutant(first_name, last_name, address, picture_location) {
    throw new Error("You need to implement the 'addMutant' function"); // Delete this line and implement the function
}

async function main() {
    try {
        await client.connect();
        await addMutant("Miles", "Morales", "42 Brooklyn St", "https://tinyurl.com/milesmorales123");
        await showMutantData();
        if (await checkForMutant("Miles", "Morales")) {
            console.log("Congratulations! You've successfully added Miles in the mutant database and have passed the challenge!");
        }
    } catch (err) {
        console.error('Error:', err.message);
    } finally {
        await client.shutdown();
    }
}

main(); 