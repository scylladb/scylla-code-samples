"use strict";
var cassandra = require('cassandra-driver');
var fs = require('fs');
var responseData = '';
var client = new cassandra.Client({
  contactPoints: ['scylla-node1', 'scylla-node2', 'scylla-node3'],
  keyspace: 'tracking'
});

var insertData = function(first_name, last_name, timestamp, heat, location, speed, telepathy_powers, file) {
  console.log('\nAdding File: ' + file);
  fs.readFile(file, function(err, data) {
    if (err) {
      return console.log(err);
    } else {
      var query = 'INSERT INTO tracking_data (first_name,last_name,timestamp,data,filename,heat,location,speed,telepathy_powers) VALUES (?,?,?,?,?,?,?,?,?);';
      const parms = [first_name, last_name, timestamp, data, file, heat, location, speed, telepathy_powers];
      client.execute(query, parms, {
        prepare: true
      }, function(err, result) {
        if (err) {
          console.log('\n' + err);
        }
      });
    }
  });
};

var alterTable = function() {
  console.log('\nDeleting old columns......');
  var query = 'ALTER table tracking_data DROP data';
  client.execute(query, function(err, result) {
    var query = 'ALTER table tracking_data DROP filename';
    client.execute(query, function(err, result) {
      console.log('\nAdding data column......');
      var query = 'ALTER table tracking_data ADD data blob';
      client.execute(query, function(err, result) {
        console.log('\nAdding filename column......');
        var query = 'ALTER table tracking_data ADD filename text';
        client.execute(query, function(err, result) {});
      });
    });
  });
};

var getData = function(first_name, last_name, filename) {
  var output_file = filename.split('/');
  console.log('\nTrying to retrieve ' + filename);
  var query = 'select data from tracking_data where first_name = ? and last_name = ?';
  const parms = [first_name, last_name];
  client.execute(query, parms, {
    prepare: true
  }, function(err, result) {
    if (err) {
      console.log('\n' + err);
    } else {
      if (result.rows[0]) {
        fs.writeFile('/tmp/' + output_file[output_file.length - 1], result.rows[0].data, (err) => {
          console.log('\nWrote /tmp/' + output_file[output_file.length - 1]);
        });
      } else {
        console.log('\nNo Data Found for ' + filename);
      }
    }
  });
};

module.exports.alterTable = alterTable;
module.exports.insertData = insertData;
module.exports.getData = getData;