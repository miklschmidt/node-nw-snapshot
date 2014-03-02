###
# Dependencies
###

Config       = require "./config"
Snapshot     = require "./snapshot"
PubSubSocket = require "./pubsub"
express      = require 'express'

###
# Server definition
###

module.exports =
	http: null
	socket: null
	app: null
	start: () ->
		@socket = new PubSubSocket
		that = @
		@socket.on 'message', (nwVersion, appSourceNw, snapshotSource, iterations) ->
			Snapshot.config {
				nwVersion: nwVersion.toString(), 
				appSourceNw, 
				snapshotSource, 
				iterations: parseInt(iterations)
			}
			Snapshot.prepare()
			.then Snapshot.run
			.progress (status, tries) ->
				that.socket.send 'progress', status.toString(), tries.toString()
			.fail (err, tries) ->
				that.socket.send 'fail', err.toString(), tries?.toString() or '0'
			.done (snapshot, tries) ->
				that.socket.send 'done', snapshot, tries.toString()
			.always () ->
				Snapshot.resetState()

		@socket.bind(Config.sockPort, Config.hostIP)

		@app = express()

		@app.get '/callback/:id', (req, res) ->
			res.header('Cache-Control', 'no-cache, private, no-store, must-revalidate, max-stale=0, post-check=0, pre-check=0');
			res.header('Expires', 'Fri, 31 Dec 1998 12:00:00 GMT');
			Snapshot.notify req.params.id
			res.end()

		@http = @app.listen Config.httpPort

		return {@app, @http, @socket}

	stop: () ->
		@socket.close()
		@http.close()
		@http = null
		@app = null
		@socket = null