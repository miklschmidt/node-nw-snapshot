Latest version: 0.2.0

## NOTE: Upgrading from 0.1.x to 0.2.x
The default ports have changed to make room for x64 on osx and windows. See [defaults](#defaults)

## Introduction

node-nw-snapshot is a cross platform buildserver and client for compiling and testing v8 snapshots of [node-webkit](github.com/rogerwang/node-webkit) code. It's simple to get up and running, if you already have virtual or local machine's running the needed operating systems. It will compile snapshots for any node-webkit version above v0.4.2, and automatically download the specified version for compilation and testing - no more manual fixing of 3 seperate vm's when upgrading your app to a new node-webkit version. 

Best of all, **no more broken snapshots** when deploying a new version of your app.

## Why does this exist?

My application [Circadio](https://getcircadio.com/) has an autoupdater that will automatically update the application when i publish a new version. I need to protect my source code, so i use snapshots. I distribute Circadio for Windows, OS X and Linux which means i need some kind of server running on all the platforms for generating the snapshots for "one button deploys". Until now, that server has been extremely minimal and basically just consisted of an exec call and a simple http server. 

I started noticing that on almost every deploy, one of my distributions would fail. After looking over my buildscripts, application code and distribution server i couldn't find the source of the problem. What worried me even more, was that on 4 consecutive deploys of the same code, the distribution that failed to run was totally random. The first time it would be the Windows distribution, the next it would be the linux32 distribution, and so on. Sometimes everything just worked. 

I finally traced the source of the problem to the snapshot. It seems that nwsnapshot will sometimes fail silently and generate a snapshot that will [cause node-webkit to crash on launch](https://github.com/rogerwang/node-webkit/issues/1295). With no way to prevent this from happening, i set out to create node-nw-snapshot.

## How it works

When the server receives a build command, it will download the specified node-webkit version as needed and inject a small test function (9 LOC) into your snapshot code. The package.json file of your app will be modified to use the generated snapshot. After that, the app will be launched with an automatically generated ID and the function will test for this id, before executing a callback to the snapshot server.

Since the function is located inside the snapshotted code, the app won't make a request to the server if the snapshot is broken. That means you can be 100% certain that the snapshot you get back will run.

Note: 3 things can happen when launching the app.

* It will work and make a request to the server (yay!)
* It will immediately crash
* It will hang forever.

In the last case there's a timeout of 10s before the process is terminated and the snapshot is deemed broken.

## Security

Since the code you will be snapshotting is probably propriatary (if not, why snapshot?) you probably don't want to pass your code across the web. node-nw-snapshot uses insecure sockets (based on [Axon](github.com/visionmedia/axon)) to communicate between clients and servers, and your code will be transferred in plain text (for now). You will probably want to keep your servers on the local network (i use VirtualBox). Besides this concern there is no reason your servers couldn't be located remotely.

## Installation

```bash
npm install nw-snapshot
```

## Usage

Server:

```bash
npm start nw-snapshot
```

Client:

in your buildscript:
```js
SnapshotClient = require('nw-snapshot').Client;
var client = new SnapshotClient("0.9.2", appSource, snapshotSource);
// Connect to tcp://127.0.0.1:3001
client.connect(3001, function(){
	client.on('done', function(snapshot){
		require('fs').writeFileSync(require('path').join(__dirname, 'snapshot.bin'), snapshot);
		console.log("Done compiling snapshot.");
		client.disconnect();
	});
	client.on('progress', function(err, iteration) {
		// Will run each time an iteration has failed.
		console.log("Iteration #" + iteration + " failed: " + err);
	});
	client.on('fail', function(err, tries){
		console.log("Failed to compile snapshot. Tried " + tries + " times.");
	});
	// Run a maximum of 5 iterations.
	client.build(5);
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

#### Testing

Start by cloning the repository:
```bash
git clone https://github.com/miklschmidt/node-nw-snapshot.git
cd node-nw-snapshot
npm install -g gulp
npm install
```

The tests use a minimally modified version of the [frameless-window](https://github.com/zcbenz/nw-sample-apps/tree/master/frameless-window) example from the official node-webkit example applications. 

```bash
gulp test
```

Want to test the ratio at which nwsnapshot will fail?
```
gulp test-nwsnapshot
```

On OSX with v0.8.1, nwsnapshot will produce a broken snapshot ~40 out of 100 runs.

#### <a name="defaults"></a> Defaults

##### Server socket ports:

* osx32 servers will use 3001
* osx64 servers will use 3002
* win32 servers will use 3011
* win64 servers will use 3012
* linux32 servers will use 3021
* linux64 servers will use 3022

##### Server http ports:

* osx32 servers will use 3301
* osx64 servers will use 3302
* win32 servers will use 3311
* win64 servers will use 3312
* linux32 servers will use 3321
* linux64 servers will use 3322

###### Configuration

If you're starting the server with `node server.js` or similar you can provide commandline arguments to override the http port, the socket port, and the platform architecture to compile for.
```
node server.js --arch ia32 --httpport 1234 --sockport 4321
node server.js --arch x64
node server.js --sockport 4321
```

If you're using `npm start` to start the server, you can override the default socket port by doing:
```
npm config set nw-snapshot:sockport 1234
```
and the http port:
```
npm config set nw-snapshot:httpport 4321
```
and the platform architecture to compile for:
```
npm config set nw-snapshot:arch ia32
```

##### Snapshot:
```
timeout: 10000ms # Time to wait before killing the node-webkit process and fail/try again
```

## Cool stuff

node-nw-snapshot comes with a downloader for downloading and extracting a specific version of node-webkit. You can use this class in your buildscript for automatically running your app in the version of you choosing. Here's an example using [gulp](https://github.com/gulpjs/gulp):

```javascript
var exec = require('child_process').exec;
var NodeWebkitDownloader = require('nw-snapshot').Downloader;
var gulp = require('gulp');
var gutil = require('gulp-util');

gulp.task('run', ['insert-name-of-compile-task-here'], function(callback){

	var version = gutil.env.nw || '0.9.2';
	downloader = new NodeWebkitDownloader(version);
	downloader.ensure()
	.done(function(snapshotBin, nwBin){
		appProcess = exec(nwBin + " " + path_to_you_app_folder);
		appProcess.stdout.pipe(process.stdout);
		appProcess.stderr.pipe(process.stderr);
		appProcess.on('exit', callback);
	}).fail(callback);

});
```

Now from the command line you can do:

```bash
gulp run --nw 0.8.2
```

And magic will happen!
