config = require './config.coffee'
Snapshot = require './snapshot.coffee'
socket = new (require './axon-pubsub')
express = require 'express'

socket.on 'message', (nwVersion, appSourceNw, snapshotSource, iterations) ->
	Snapshot.config {
		nwVersion: nwVersion.toString(), 
		appSourceNw, 
		snapshotSource, 
		iterations: parseInt(iterations)
	}
	Snapshot.prepare()
	.then Snapshot.run
	.progress (status, tries) ->
		socket.send 'progress', status.toString(), tries.toString()
	.fail (err, tries) ->
		socket.send 'fail', err.toString(), tries?.toString() or '0'
	.done (snapshot, tries) ->
		socket.send 'done', snapshot, tries.toString()

socket.bind("tcp://127.0.0.1:#{config.sockPort}")

app = express()

app.get '/callback/:id', (req, res) ->
	res.header('Cache-Control', 'no-cache, private, no-store, must-revalidate, max-stale=0, post-check=0, pre-check=0');
	res.header('Expires', 'Fri, 31 Dec 1998 12:00:00 GMT');
	Snapshot.notify req.params.id
	res.end()

server = app.listen config.httpPort

module.exports = {app, server, socket}