"use strict";
var cassandra = require('cassandra-driver');
var responseData = '';
var scylladb_server = process.env.SCYLLADB_SERVER;
var createKeyspace = function() {
  var client = new cassandra.Client({
    contactPoints: [scylladb_server]
  });
  client.execute("CREATE KEYSPACE twitter WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy','DC1' : 3};", function(err, result) {
    if (err) {
      console.log('\n' + err);
    }
    createTable();
  });

}
var populateData = function(date, username, tweet, url) {
  var client = new cassandra.Client({
    contactPoints: [scylladb_server],
    keyspace: 'twitter'
  });

  var query = 'INSERT INTO tweets (date,username,tweet, url) VALUES (?, ?, ?, ?)';
  const parms = [date, username, tweet, url];

  client.execute(query, parms, function(err, result) {

    if (err) {
      console.log('\n' + err);
    }
  });
};

var getData = function(callback) {
  var client = new cassandra.Client({
    contactPoints: [scylladb_server],
    keyspace: 'twitter'
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

function createTable() {
  var client = new cassandra.Client({
    contactPoints: [scylladb_server],
    keyspace: 'twitter'
  });

  client.execute("CREATE TABLE tweets (Date text ,UserName text, Tweet text, URL text,PRIMARY KEY(Date, Username));", function(err, result) {
    if (err) {
      console.log('\n' + err);
    }
  });
}
module.exports.populateData = populateData;
module.exports.createKeyspace = createKeyspace;
module.exports.getData = getData;
