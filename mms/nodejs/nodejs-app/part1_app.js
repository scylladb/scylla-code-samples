var cassandra = require('cassandra-driver');
var async = require('async');

const client = new cassandra.Client({
    contactPoints: ['scylla-node1', 'scylla-node2', 'scylla-node3'],
    localDataCenter: 'DC1',
    keyspace: 'catalog',
});

//Ensure all queries are performed in the correct order
async.series([
//Connect to the Scylla cluster
  function connect(next) {
  console.log('Connecting to Scylla cluster');
    client.connect(next);
  },
//Display all data	
   function select(next) {
    const query = 'SELECT * FROM catalog.mutant_data';
    client.execute(query,  function (err, result) {
      if (err) return next(err);

  console.log('Initial Data:');
	    for (let row of result) {

  console.log(row.first_name, ' ', row.last_name); 
}
      next();
    });
  },
//Insert additional row	
function insert(next) {
  console.log('Adding Rick Sanchez');
 const query = 'INSERT INTO mutant_data (first_name,last_name,address,picture_location) VALUES (?, ?, ?, ?)';
    const params = ['Rick', 'Sanchez', '615 East St', 'http://www.facebook.com/rsanchez'];
 client.execute(query, params, next);
  },
//Display data after insert	
   function select(next) {
  console.log('Data after INSERT:');
    const query = 'SELECT * FROM catalog.mutant_data';
    client.execute(query,  function (err, result) {
      if (err) return next(err);

	    for (let row of result) {

  console.log(row.first_name, ' ', row.last_name); 
}
      next();
    });
  },
//Delete inserted row	
function del(next) {
  console.log('Removing Rick Sanchez');

	const query = 'DELETE FROM mutant_data WHERE last_name = ? and first_name = ?';
    const params = ['Sanchez', 'Rick'];
 client.execute(query, params, next);
  },
//Display data after deletion	
   function select(next) {
  console.log('Data after DELETE:');
    const query = 'SELECT * FROM catalog.mutant_data';
    client.execute(query,  function (err, result) {
      if (err) return next(err);

	    for (let row of result) {

  console.log(row.first_name, ' ', row.last_name); 
}
      next();
    });
  },

], function (err) {
  if (err) {
    console.error('There was an error', err.message, err.stack);
  }
//Close the connection	
  console.log('Shutting down');
  client.shutdown(() => {
    if (err) {
      throw err;
    }
  });
});

