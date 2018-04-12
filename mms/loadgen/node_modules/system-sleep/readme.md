# Node.js Sleep()
for those who need Sleep() just like me.

![Sleeping Beauty](https://68.media.tumblr.com/02cbcb04de3577bc89ef3c98fdbc94ab/tumblr_oknt65m0Iv1ru9jhqo1_1280.jpg)

*31 january 2017 | UPDATE: NO LONGER REQUIRES CHILD PROCESS, using deasync instead.*

```
 @package system-sleep
 @version 1.2
 @author Jochem Stoel (http://jochemstoel.github.io)
 @license don't involve me
 ```

* will make the system wait xxx milliseconds.
* can be used to delay script execution.
* is often used to relax the system in between resource intensive tasks.
* works on every platform x86 + x64 Windows / Linux / OSX



* Existing sleep() solutions use a blocking while loop which uses 100% CPU. This is incredibly stupid.
* Also, many sleep() solutions are only for Windows or only for Linux.

### Install using NPM
```bash
npm install system-sleep
```
### Use
```javascript
var sleep = require('system-sleep');
sleep(5000); // 5 seconds
```
### Test
Prints <i><a>variable y</a></i> to the console every 1 second during 10 seconds.
```javascript
var sleep = require('system-sleep');
for (y = 0; y < 10; y++) {
	console.log(y);
	sleep(1000);
}
```

<img alt="Jochem Stoel" src="http://33.media.tumblr.com/avatar_048a728a1488_128.png" style="float: left;">