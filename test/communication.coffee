###
# Dependencies
###

should                             = require 'should'
{Snapshot, Config, Server, Client} = require '../index'
rimraf                             = require 'rimraf'
fs                                 = require 'fs'
path                               = require 'path'
dfd                                = require('jquery-deferred').Deferred

###
# Fixtures
###

fixtures =
	app: null
	snapshotSource: null
	iterations: 1

nwVersion = '0.9.2'

###
# Tests
###

describe "Client / Server", () ->

	client = null

	before (done) ->
		fixtures.app = fs.readFileSync (path.join __dirname, 'fixtures', 'app.zip')
		fixtures.snapshotSource = fs.readFileSync (path.join __dirname, 'fixtures', 'snapshot.js')
		Server.start()
		client = new Client nwVersion, fixtures.app, fixtures.snapshotSource
		client.connect "tcp://#{Config.hostIP}:#{Config.sockPort}", done

	after () ->
		client.disconnect()
		Server.stop()

	describe "pubsub socket", () ->

		it "server should build when message is recieved and report back to client", (done) ->

			# Mock the snapshot config function so we will know 
			# if the server starts to build.
			oldConfig = Snapshot.config
			oldPrepare = Snapshot.prepare
			Snapshot.config = (opts) ->
				opts.nwVersion.should.be.equal nwVersion
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


	describe "http callback route", () ->

		it "should notify the snapshotter when requested", (done) ->

			sentID = "test"
			oldNotify = Snapshot.notify
			Snapshot.notify = (receivedID) ->
				receivedID.should.be.equal sentID
				Snapshot.notify = oldNotify
				done()

			require('request').get "http://127.0.0.1:#{Config.httpPort}/callback/test", (err, response, body) ->
				throw err if err
				response.statusCode.should.be.equal 200

	describe "all", () ->
		this.timeout(120000)
		it "should do everything (stupid catch all test)", (done) ->
			client.build 1
			# client.on 'progress', (status, tries) -> console.log 'progress:', status, tries
			client.on 'fail', (err, tries) -> 
				# console.log 'fail:', err, tries
				done()
			client.on 'done', (snapshot, tries) -> 
				# console.log 'done:', snapshot, tries
				done()
		after () ->
			client.removeAllListeners()
