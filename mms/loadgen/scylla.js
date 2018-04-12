"use strict";
var cassandra = require('cassandra-driver');
var responseData = '';

var populateData = function(first_name, last_name, timestamp, heat, location, speed, telepathy_powers, date) {
  var client = new cassandra.Client({
    contactPoints: ['scylla-node1', 'scylla-node2', 'scylla-node3'],
    keyspace: 'tracking'
  });

  var query = 'INSERT INTO tracking_data (first_name,last_name,timestamp,heat,location,speed,telepathy_powers) VALUES (?,?,?,?,?,?,?);';
  const parms = [first_name, last_name, timestamp, heat, location, speed, telepathy_powers];
  client.execute(query, parms, {
    prepare: true
  }, function(err, result) {
    if (err) {
      console.log('\n' + err);
    }
  });
};

var getData = function(callback) {
  var client = new cassandra.Client({
    contactPoints: [scylladb_server],
    keyspace: 'tracking'
  });

  var query = 'select * from tweets;';

  client.execute(query, function(err, result) {
    if (err) {
      callback('\n' + err);
    } else {
      callback(JSON.stringify(result));
    }
  });
};

module.exports.populateData = populateData;
module.exports.getData = getData;