"use strict";
var cassandra = require('cassandra-driver');
var fs = require('fs');
var responseData = '';
var client = new cassandra.Client({
  contactPoints: ['scylla-node1', 'scylla-node2', 'scylla-node3'],
  keyspace: 'catalog'
});

var insertData = function(first_name, last_name, address, picture_location, data) {
  client.keyspace = 'catalog';
  var query = 'INSERT INTO mutant_data (first_name,last_name, address, picture_location, data) VALUES (?,?,?,?,?);';
  const parms = [first_name, last_name, address, picture_location, data];
  client.execute(query, parms, {
    prepare: true
  }, function(err, result) {
    if (err) {
      console.log('\n' + err);
    }
  });
};

var alterTable = function() {
  client.keyspace = 'catalog';
  console.log('\nDeleting old columns......');
  var query = 'ALTER table mutant_data DROP data';
  client.execute(query, function(err, result) {
    console.log('\nAdding data column......');
    var query = 'ALTER table mutant_data ADD data blob';
    client.execute(query, function(err, result) {});
  });
};

var getTracking = function(first_name, last_name, callback) {
  client.keyspace = 'tracking';
  var query = 'select * from tracking_data where first_name=? and last_name=? ORDER BY timestamp DESC;';
  const parms = [first_name, last_name];
  client.execute(query, parms, {
    prepare: true
  }, function(err, result) {
    if (err) {
      console.log('\n' + err);
    } else {
      if (result) {
        return callback(result);
      } else {
        console.log('\nError, no results');
      }
    }
  });
};



var getData = function(callback) {
  client.keyspace = 'catalog';
  var query = 'select * from mutant_data;';
  client.execute(query, function(err, result) {
    if (err) {
      console.log('\n' + err);
    } else {
      if (result) {
        return callback(result);
      } else {
        console.log('\nError, no results');
      }
    }
  });
};

module.exports.alterTable = alterTable;
module.exports.insertData = insertData;
module.exports.getData = getData;
module.exports.getTracking = getTracking;