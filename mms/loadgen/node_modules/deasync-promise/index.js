var loop = require('deasync').runLoopOnce;

module.exports = function(promise) {
	var result, error, done = false;
	promise.then(function(res) {
		result = res;
	}, function(err) {
		error = err;
	}).then(function() {
		done = true;
	});
    while(!done) {
        loop();
    }
    if (error) {
    	throw error;
    }
    return result;
}