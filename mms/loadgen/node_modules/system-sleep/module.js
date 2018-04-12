/* Sleep function for Node.
 * 
 * @package system-sleep
 * @version 1.0
 * @author Jochem Stoel (http://jochemstoel.github.io)
 * @license don't involve me
 */

const sleep = interval => new Promise((deliver, renege) => {
	try {
		setTimeout(() => {
			deliver(
				new Date().getTime()
			)
		}, interval)
	} catch (exception) {
		renege(
			exception.message
		)
	}
})
module.exports = interval => {
	try {
		return require('deasync-promise')(
			sleep(interval)
		)
	} catch (notAsync) { /* https://github.com/jochemstoel/nodejs-system-sleep/issues/4 */
		require('child_process').execSync(
			`"${process.execPath}"` + " -e \"setTimeout(function () { return true; }, " + interval + ");\""
		)
		return null
	}
}
