var cassandra = require('cassandra-driver');
var scylla = require("./scylla.js");
const bodyParser = require('body-parser');
const http = require('http');
const express = require('express');
const app = express();
const fs = require('fs');
const multer = require('multer');
app.use(bodyParser());
const upload = multer({
  dest: '../'
});

app.get('/alter', (req, res) => {
  scylla.alterTable(function() {});
  res.end();
});

app.get('/jquery.min.js', (req, res) => {
  res.sendFile(__dirname + '/jquery.min.js');
});

app.get('/jquery-ui.js', (req, res) => {
  res.sendFile(__dirname + '/jquery-ui.js');
});

app.get('/dropzone.js', (req, res) => {
  res.sendFile(__dirname + '/dropzone.js');
});

app.get('/style.css', (req, res) => {
  res.sendFile(__dirname + '/style.css');
});

app.get('/menu.css', (req, res) => {
  res.sendFile(__dirname + '/menu.css');
});

app.get('/', (req, res) => {
  res.sendFile(__dirname + '/index.html');
});

app.get('/blank', (req, res) => {
  res.sendFile(__dirname + '/blank.html');
});

app.get('/catalog.html', (req, res) => {
  res.sendFile(__dirname + '/catalog.html');
});

app.get('/add-mutant.html', (req, res) => {
  res.sendFile(__dirname + '/add-mutant.html');
});

app.get('/edit.png', (req, res) => {
  res.sendFile(__dirname + '/edit.png');
});

app.get('/mms.png', (req, res) => {
  res.sendFile(__dirname + '/mms.png');
});

app.get('/load', (req, res) => {
  scylla.load();
  res.end();
});

app.get('/stopload', (req, res) => {
  scylla.stopload();
  res.end();
});

app.get('/image.png', (req, res) => {
  res.sendFile(__dirname + '/image.png');
});

app.get('/delete.png', (req, res) => {
  res.sendFile(__dirname + '/delete.png');
});

app.post('/upload', upload.single('file'), function(req, res, next) {
  const first_name = req.body.first_name;
  const last_name = req.body.last_name;
  const address = req.body.address;
  const picture_location = req.body.picture_location;
  if (req.file) {
    fs.readFile(req.file.path, (err, data) => {
      scylla.insertData(first_name, last_name, address, picture_location, data, req.file.originalname);
    });
  } else {
    fs.readFile('/webconsole/question.jpeg', (err, data) => {
      scylla.insertData(first_name, last_name, address, picture_location, data);
    });
  }
});

app.get('/pictures', (req, res) => {
  var foo = scylla.getData(function(response) {
    res.send(response);
  });
});

app.get('/tracking', (req, res) => {
  const first_name = req.body.first_name;
  const last_name = req.body.last_name;
  var foo = scylla.getTracking(first_name, last_name, function(response) {
    res.send(response);
  });
});

app.post('/pictures', (req, res) => {
  const first_name = req.body.first_name;
  const last_name = req.body.last_name;
  const file = req.body.file;
  scylla.insertData(first_name, last_name, file);
  res.end();
});

app.post('/delete', (req, res) => {
  const first_name = req.body.first_name;
  const last_name = req.body.last_name;
  scylla.deleteData(first_name, last_name);
  res.end();
});

app.post('/tracking', (req, res) => {
  const first_name = req.body.first_name;
  const last_name = req.body.last_name;
  var foo = scylla.getTracking(first_name, last_name, function(response) {
    res.send(response);
  });
});

const server = http.createServer(app);
server.listen('80', () => {
  console.log('Listening on port %d', '80');
});