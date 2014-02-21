should = require 'should'
Snapshot = require '../snapshot.coffee'
rimraf = require 'rimraf'
fs = require 'fs'
path = require 'path'
config = require '../config.coffee'
dfd     = require('jquery-deferred').Deferred

fixtures =
	app: null
	snapshotSource: null
	iterations: 1

before () ->
	fixtures.app = fs.readFileSync (path.join __dirname, 'fixtures', 'app.zip')
	fixtures.snapshotSource = fs.readFileSync (path.join __dirname, 'fixtures', 'snapshot.js')

describe "Client / Server", () ->

	client = null
	server = null

	before (done) ->
		server = require '../server'
		client = new (require '../client.coffee') '0.8.1', fixtures.app, fixtures.snapshotSource
		client.connect config.sockPort, done

	after () ->
		client.disconnect()
		server.socket.close()
		server.server.close()

	describe "pubsub socket", () ->

		it "server should build when message is recieved and report back to client", (done) ->

			# Mock the snapshot config function so we will know 
			# if the server starts to build.
			oldConfig = Snapshot.config
			oldPrepare = Snapshot.prepare
			Snapshot.config = (opts) ->
				opts.nwVersion.should.be.equal '0.8.1'
				opts.appSourceNw.length.should.be.equal fixtures.app.length
				opts.snapshotSource.length.should.be.equal fixtures.snapshotSource.length
			Snapshot.prepare = () ->
				return dfd().reject(new Error('mock!'), 0).promise()

			client.on 'fail', () ->
				Snapshot.config = oldConfig
				Snapshot.prepare = oldPrepare
				client.removeAllListeners()
				done()

			client.build fixtures.iterations
			# setTimeout () ->
			# 	done()
			# , 1500


	describe "http callback route", () ->

		it "should notify the snapshotter when requested", (done) ->

			sentID = "test"
			oldNotify = Snapshot.notify
			Snapshot.notify = (receivedID) ->
				receivedID.should.be.equal sentID
				Snapshot.notify = oldNotify
				done()

			require('request').get "http://127.0.0.1:#{config.httpPort}/callback/test", (err, response, body) ->
				throw err if err
				response.statusCode.should.be.equal 200

	# describe "all", () ->
	# 	this.timeout(120000)
	# 	it "should do everything (this is so", (done) ->
	# 		client.build 1
	# 		client.on 'progress', (status, tries) -> console.log 'progress:', status, tries
	# 		client.on 'fail', (err, tries) -> 
	# 			console.log 'fail:', err, tries
	# 			done()
	# 		client.on 'done', (snapshot, tries) -> 
	# 			console.log 'done:', snapshot, tries
	# 			done()
					