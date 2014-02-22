# Introduction

node-nw-snapshot is a cross platform buildserver and client for compiling and testing v8 snapshots of node-webkit code. Very simple to get up and running, if you already have virtual machine's running the needed operating systems. It will compile snapshots for any node-webkit version above v0.4.2, and automatically download the specified version for compilation and testing - no more manual fixing of 3 seperate vm's when upgrading your app to a new node-webkit version. Best of all - no more broken snapshots when deploying a new version of your app.

# Why does this exist?

In Circadio, i have an autoupdater that will automatically update the application when i publish a new version. I need to protect my source code, so i use snapshots. I distribute circadio for Windows, OS X and Linux. I started noticing that on almost every deploy, one of my distributions would fail. After looking over my buildscripts, deployscripts, application code and distribution server i couldn't find the source of the problem. What worried me even more, was that on 4 consecutive deploys of the same code, the distribution that failed to run was totally random. One time it would be the Windows distribution, the other it would be the linux32 distribution, and so on. I finally traced the source of the problem to the snapshot. It seems that nwsnapshot will fail silently ALOT. With no way to prove or prevent this from happening, i set out to create node-nw-snapshot.

# How it works

When the server receives a build command, it will download the specified node-webkit version as needed and inject a small test function (9 LOC) into your snapshot code. The app will be launched with an automatically generated ID and the function will test for this id before executing a callback to the snapshot server.

Since the function is located inside the snapshotted code, the app won't request the server if the snapshot is broken. That means you can be 100% certain that your snapshot will run.

# Usage

On server(s):

```bash
npm install nw-snapshot
npm start
```

On client:

```bash
npm install nw-snapshot
```

in you buildscript:
```js
SnapshotClient = require('nw-snapshot').Client;
var client = new SnapshotClient("0.9.2", appSource, snapshotSource);
client.connect(3001);
client.build(1);
client.on('done', function(snapshot){
	require('fs').writeFileSync(require('path').join(__dirname, 'snapshot.bin'));
});
```
appSource should be either a `Buffer` of your application zip (app.nw) without the snapshot, or the path to it.
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

Wan't to test the ratio at which nwsnapshot will fail?
```
./node_modules/.bin/mocha --compilers coffee:coffee-script/register -R spec test/snapshot.coffee
```

On OSX with 0.8.1, nwsnapshot will make a broken snapshot ~48 out of 100 runs.

#### Defaults

##### Server socket ports:

osx servers will use 3001
win32 servers will use 3002
linux32 servers will use 3003
linux64 servers will use 3004

##### Server http ports:

osx servers will use 3301
win32 servers will use 3302
linux32 servers will use 3303
linux64 servers will use 3304

##### Snapshot:
timeout: 10000ms (time to wait before killing the node-webkit process and fail/try again)