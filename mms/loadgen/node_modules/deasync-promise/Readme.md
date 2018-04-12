# deasync-promise

Transforms async functions into sync with promise API

## Usage

```js
import deasyncPromise from 'deasync-promise';
let promiseWhichWillBeResolved = generateSuccessPromise();
let syncResult = deasyncPromise(promiseWhichWillBeResolved)

let promiseWhichWillBeRejected = generateRejectedPromise();
try {
    let syncResult = deasyncPromise(promiseWhichWillBeRejected)
} catch (err) {
}
```