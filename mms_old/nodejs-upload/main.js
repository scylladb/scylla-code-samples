var cassandra = require('cassandra-driver');
var scylla = require("./scylla.js");
const bodyParser = require('body-parser');
const http = require('http');
const express = require('express');
const app = express();
app.use(bodyParser());

var get_year = new Date();
var year = get_year.getFullYear();
var hour = Math.round(Math.random() * (23 - 1) + 1);
var minute = Math.round(Math.random() * (59 - 1) + 1);
var day = Math.round(Math.random() * (30 - 1) + 1);
var month = Math.round(Math.random() * (12 - 1) + 1);
var timestamp = year + '-' + month + '-' + day + ' ' + hour + ':' + minute + '+0000';
var speed = Math.round(Math.random() * (100 - 1) + 1);
var heat = Math.round(Math.random() * (50 - 1) + 1);
var telepathy_powers = Math.round(Math.random() * (50 - 1) + 1);
var location = 'Hell';

app.get('/alter', (req, res) => {
  scylla.alterTable(function() {});
  res.end();
});

app.get('/', (req, res) => {
  const first_name = req.query.first_name;
  const last_name = req.query.last_name;
  const file = req.query.file;
  scylla.getData(first_name, last_name, file);
  res.end();
});

app.post('/', (req, res) => {
  const first_name = req.body.first_name;
  const last_name = req.body.last_name;
  const file = req.body.file;
  scylla.insertData(first_name, last_name, timestamp, heat, location, speed, telepathy_powers, file);
  res.end();
});

const server = http.createServer(app);
server.listen('80', () => {
  console.log('Listening on port %d', '80');
});



//
//scylla.insertData("Bob", "Loblaw", timestamp, heat, location, speed, telepathy_powers, '/bin/sh');

//scylla.getData("Bob", "Loblaw", "/bin/sh", function() {});