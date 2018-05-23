var database = require('./scylla');
var first_name = 'Jim';
var last_name = 'Jeffries';
var location = 'New York';

function load() {
  setTimeout(function() {
    var get_year = new Date();
    var year = get_year.getFullYear();
    var hour = Math.round(Math.random() * (23 - 1) + 1);
    var minute = Math.round(Math.random() * (59 - 1) + 1);
    var day = Math.round(Math.random() * (30 - 1) + 1);
    var month = Math.round(Math.random() * (12 - 1) + 1);
    var timestamp = year + '-' + month + '-' + day + ' ' + hour + ':' + minute + '+0000';
    database.populateData('Jim', 'Jeffries', timestamp, Math.round(Math.random() * (50 - 1) + 1), 'New York', Math.round(Math.random() * (100 - 1) + 1), Math.round(Math.random() * (50 - 1) + 1));
    database.populateData('Bob', 'Loblaw', timestamp, Math.round(Math.random() * (50 - 1) + 1), 'Cincinatti', Math.round(Math.random() * (100 - 1) + 1), Math.round(Math.random() * (50 - 1) + 1));
    database.populateData('Bob', 'Zemuda', timestamp, Math.round(Math.random() * (50 - 1) + 1), 'San Francisco', Math.round(Math.random() * (100 - 1) + 1), Math.round(Math.random() * (50 - 1) + 1));
    database.populateData('Jim', 'Jeffries', timestamp, Math.round(Math.random() * (50 - 1) + 1), 'New York', Math.round(Math.random() * (100 - 1) + 1), Math.round(Math.random() * (50 - 1) + 1));
    database.populateData('Alex', 'Jones', timestamp, Math.round(Math.random() * (50 - 1) + 1), 'Cincinatti', Math.round(Math.random() * (100 - 1) + 1), Math.round(Math.random() * (50 - 1) + 1));
    database.populateData('Steven', 'Crowder', timestamp, Math.round(Math.random() * (50 - 1) + 1), 'Cincinatti', Math.round(Math.random() * (100 - 1) + 1), Math.round(Math.random() * (50 - 1) + 1));
    load();
  }, 50);
}

console.log('\nWill start in 60 seconds......: ');
setTimeout(function() {
  console.log('\n\nPopulating data......: ');
  load();
}, 60000);