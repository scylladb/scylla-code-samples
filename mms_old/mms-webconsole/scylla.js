"use strict";
var cassandra = require('cassandra-driver');
var fs = require('fs');
var responseData = '';
var client = new cassandra.Client({
  contactPoints: ['scylla-node1', 'scylla-node2', 'scylla-node3'],
  keyspace: 'catalog'
});
var loadclient = new cassandra.Client({
  contactPoints: ['scylla-node1', 'scylla-node2', 'scylla-node3'],
  keyspace: 'tracking'
});
var loadtool = '';

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

var deleteData = function(first_name, last_name) {
  var query = 'DELETE FROM mutant_data WHERE first_name = ? AND last_name = ?;';
  const parms = [first_name, last_name];
  client.execute(query, parms, {
    prepare: true
  }, function(err, result) {
    if (err) {
      console.log('\n' + err);
    }
  });
};

var alterTable = function() {
  console.log('\nDeleting old columns......');
  var query = 'ALTER table mutant_data DROP data';
  client.execute(query, function(err, result) {
    console.log('\nAdding data column......');
    var query = 'ALTER table mutant_data ADD data blob';
    client.execute(query, function(err, result) {});
  });
};

var populateData = function(first_name, last_name, timestamp, heat, location, speed, telepathy_powers, date) {
  var query = 'INSERT INTO tracking_data (first_name,last_name,timestamp,heat,location,speed,telepathy_powers) VALUES (?,?,?,?,?,?,?);';
  const parms = [first_name, last_name, timestamp, heat, location, speed, telepathy_powers];
  loadclient.execute(query, parms, {
    prepare: true
  }, function(err, result) {
    if (err) {
      console.log('\n' + err);
    }
  });
};


function stopload() {
  clearTimeout(loadtool);
}


function load() {
  var first_name = [];
  var last_name = [];
  var locations = ['New York', 'Cincinnati', 'Las Vegas', 'San Francisco', 'Austin', 'Dallas', 'Chicago', 'Reno'];
  var get_names = getData(function(data) {
    first_name.length = data.rows.length;
    last_name.length = first_name.length;
    for (var i = 0; i != data.rows.length; i++) {
      first_name[i] = data.rows[i].first_name;
      last_name[i] = data.rows[i].last_name;
    }
  });

  loadtool = setTimeout(function() {
    for (var i = 0; i != first_name.length; i++) {
      var get_year = new Date();
      var year = get_year.getFullYear();
      var hour = Math.round(Math.random() * (23 - 1) + 1);
      var minute = Math.round(Math.random() * (59 - 1) + 1);
      var day = Math.round(Math.random() * (30 - 1) + 1);
      var month = Math.round(Math.random() * (12 - 1) + 1);
      var timestamp = year + '-' + month + '-' + day + ' ' + hour + ':' + minute + '+0000';
      populateData(first_name[i], last_name[i], timestamp, Math.round(Math.random() * (50 - 1) + 1), locations[Math.floor(Math.random() * locations.length)], Math.round(Math.random() * (100 - 1) + 1), Math.round(Math.random() * (50 - 1) + 1));
    }
    load();
  }, 50);
}

var getTracking = function(first_name, last_name, callback) {
  var query = 'select * from tracking_data where first_name=? and last_name=? ORDER BY timestamp DESC;';
  const parms = [first_name, last_name];
  loadclient.execute(query, parms, {
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

module.exports.stopload = stopload;
module.exports.load = load;
module.exports.alterTable = alterTable;
module.exports.insertData = insertData;
module.exports.getData = getData;
module.exports.deleteData = deleteData;
module.exports.getTracking = getTracking;