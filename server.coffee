config = require './config.coffee'
Snapshot = require './snapshot.coffee'
sock = require './axon-pubsub'
express = require 'express'
sock.subscribe('build')

sock.on 'message', (opts) ->
	buildDeferred = dfd()
	Snapshot.config(opts, sock)
	Snapshot.prepare()
	.then(Snapshot.build_and_test)
	.progress((status, tries) ->
		sock.send 'progress', status, tries
	).fail((err, tries) ->
		sock.send 'fail', tries
	).done (snapshot, tries) ->
		sock.send 'success', snapshot, tries

sock.bind(config.sockPort)

answerBackServer = express()

answerBackServer.get '/callback/:id', (req, res) ->
	Snapshot.notify req.params.id
	res.end(200)

answerBackServer.listen(config.answerPort)


#TODO: Get an answer back from Circadio... somehow...






# OLD

server.get '/answerback', (req, res) ->

server.post '/', (req, res) ->
	source_file = req.files.source.path # The file to snapshot
	package_json = req.packageDescription # The package.json file (used for testing)
	nw_version = req.nwVersion # The version of node-webkit to compile for and test against

	try





server.listen(config.port)
console.log "Node-webkit buildserver running on port " + config.port