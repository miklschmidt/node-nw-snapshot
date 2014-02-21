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
	Snapshot.notify req.params.id
	res.end()

server = app.listen config.httpPort

module.exports = {app, server, socket}