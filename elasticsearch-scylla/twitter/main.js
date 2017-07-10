var Twitter = require('twitter');
var request = require('request');
var elasticsearch = require('./elasticsearch');
var database = require('./createKeyspace');
var express = require('express');
var app = express();
var sleep = require('system-sleep')
var server = require("http").createServer(app);
//Twitter Account Variables
var consumer_key = process.env.consumer_key;
var consumer_secret = process.env.consumer_secret;
var access_token_key = process.env.access_token_key;
var access_token_secret = process.env.access_token_secret;
var twitter_topic = process.env.twitter_topic;
var write_to_scylla = '1';

//elasticsearch server info
var elasticsearch_url = process.env.elasticsearch_url;

var client = new Twitter({
  "consumer_key": consumer_key,
  "consumer_secret": consumer_secret,
  "access_token_key": access_token_key,
  "access_token_secret": access_token_secret
});

function search_twitter() {

  var stream = client.stream('statuses/filter', {
    track: twitter_topic
  });

  stream.on('data', function(event) {
    if (event.created_at && event.user.screen_name && event.text && event.id_str) {
      if (write_to_scylla) {
        database.populateData(event.created_at, event.user.screen_name, event.text, 'https://twitter.com/' + event.user.screen_name + '/status/' + event.id_str);
        sleep(.1 * 1000);
      }
    }
  });

  stream.on('error', function(error) {
    console.log('\nAn error has occurred.\n' + error + '\n');
  });

  stream.on('close', function(message) {
    console.log('\n\nConnection Closed. Restarting Stream.\n\n');
    search_twitter();
  });
}

app.get('/stop', function(req, res) {
  write_to_scylla = '';
  console.log('\nStopping writes to Scylla');
  res.end('\nStopping writes to Scylla');
});

app.get('/start', function(req, res) {
  write_to_scylla = '1';
  console.log('\nAllowing writes to Scylla');
  res.end('\nAllowing writes to Scylla');
});

function dump_data() {
  var get_scylla_data = database.getData(function(received_data) {
    var data = JSON.parse(received_data);
    for (var key in data.rows) {
      if (data.rows.hasOwnProperty(key)) {
        elasticsearch.sendData(data.rows[key].date, data.rows[key].username, data.rows[key].tweet, data.rows[key].url);
        sleep(.1 * 1000);
      };
    };
    console.log('\nData dump complete');
  });
}

app.get('/dump', function(req, res) {
  elasticsearch.clear_data();
  setTimeout(function() {
    dump_data();
  }, 3000);
  res.end('\nSent request to dump data to elasticseaerch');
});

server.listen('8080', function() {
  console.log('Listening on port %d', 8080);
});

if (consumer_key && consumer_secret && access_token_key && elasticsearch_url && twitter_topic) {
  setTimeout(function() {
    console.log('\nCreating keyspace.....');
    database.createKeyspace();
    elasticsearch.create_mapping();
    setTimeout(function() {
      console.log('\nLooking for: ' + twitter_topic);
      search_twitter();
    }, 10000);
  }, 60000);
} else {
  console.log('\n[Error: Missing arguments!]\n');
}
