# Introduction

node-nw-snapshot is a cross platform buildserver and client for compiling and testing v8 snapshots of [node-webkit](github.com/rogerwang/node-webkit) code. It's simple to get up and running, if you already have virtual or local machine's running the needed operating systems. It will compile snapshots for any node-webkit version above v0.4.2, and automatically download the specified version for compilation and testing - no more manual fixing of 3 seperate vm's when upgrading your app to a new node-webkit version. Best of all - no more broken snapshots when deploying a new version of your app.

# Why does this exist?

My product [Circadio](https://getcircadio.com/) has an autoupdater that will automatically update the application when i publish a new version. I need to protect my source code, so i use snapshots. I distribute Circadio for Windows, OS X and Linux. I started noticing that on almost every deploy, one of my distributions would fail. After looking over my buildscripts, application code and distribution server i couldn't find the source of the problem. What worried me even more, was that on 4 consecutive deploys of the same code, the distribution that failed to run was totally random. One time it would be the Windows distribution, the other it would be the linux32 distribution, and so on. Sometimes everything just worked. I finally traced the source of the problem to the snapshot. It seems that nwsnapshot will sometimes fail silently and generate a snapshot that will cause node-webkit to crash on launch. With no way to prove or prevent this from happening, i set out to create node-nw-snapshot.

# How it works

When the server receives a build command, it will download the specified node-webkit version as needed and inject a small test function (9 LOC) into your snapshot code. The app will be launched with an automatically generated ID and the function will test for this id before executing a callback to the snapshot server.

Since the function is located inside the snapshotted code, the app won't request the server if the snapshot is broken. That means you can be 100% certain that your snapshot will run.

# Security

Since the code you will be snapshotting is probably propriatary (if not, why snapshot?) you probably don't want to pass your code along the internet. node-nw-snapshot uses unprotected sockets (based on [Axon](github.com/visionmedia/axon)) to communicate between clients and servers, and your code will be distributed in plain text (for now). You will probably want to keep your servers on the local network (i use VirtualBox). Besides this concern there is no reason your servers couldn't be located remotely, like on Amazon AWS.

# Usage

Server:

```bash
npm install nw-snapshot
npm start
```

Client:

```bash
npm install nw-snapshot
```

in your buildscript:
```js
SnapshotClient = require('nw-snapshot').Client;
var client = new SnapshotClient("0.9.2", appSource, snapshotSource);
// Connect to tcp://127.0.0.1:3001
client.connect(3001);
// Run a maximum of 5 iterations.
client.build(iterations = 5);
client.on('done', function(snapshot){
	require('fs').writeFileSync(require('path').join(__dirname, 'snapshot.bin'));
});
client.on('progress', function(err, iteration) {
	// Will run each time an iteration has failed.
	console.log("Iteration #" + iteration + " failed: " + err);
});
client.on('fail', function(err, tries){
	console.log("Failed to compile snapshot. Tried " + tries + " times.");
});
```
appSource should be either a `Buffer` of, or the path to, your application zip (app.nw) without the code for the snapshot.
snapshotSource is the js file that you want to compile into a snapshot.

In your app's main .html file insert this snippet at the bottom of `<body>`:
```html
<script>
if (typeof __buildcallbackWrapper === 'function') __buildcallbackWrapper();
</script>
```

##### Testing

```bash
npm install nw-snapshot
npm test
```

Want to test the ratio at which nwsnapshot will fail?
```
./node_modules/.bin/mocha --compilers coffee:coffee-script/register -R spec test/snapshot.coffee
```

On OSX with v0.8.1, nwsnapshot will produce a broken snapshot ~48 out of 100 runs.

#### Defaults

##### Server socket ports:
```
osx servers will use 3001
win32 servers will use 3002
linux32 servers will use 3003
linux64 servers will use 3004
```
##### Server http ports:
```
osx servers will use 3301
win32 servers will use 3302
linux32 servers will use 3303
linux64 servers will use 3304
```
##### Snapshot:
```
timeout: 10000ms #time to wait before killing the node-webkit process and fail/try again
```