config = require './config.coffee'
Snapshot = require './snapshot.coffee'
rpc = require 'axon-rpc'
axon = require 'axon'
rep = axon.socket 'rep'

server.expose 'build', (opts, callback) ->
	buildDeferred = dfd()
	Snapshot.config(opts)
	Snapshot.prepare()
	.then(Snapshot.build_and_test)
	.always(callback)



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