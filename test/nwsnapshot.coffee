###
# Dependencies
###

should                   = require 'should'
{Config, Server, Client} = require '../index'
fs                       = require 'fs'
path                     = require 'path'

###
# Fixtures
###

fixtures =
	app: null
	snapshotSource: null
	iterations: 50

###
# Tests
###

describe "nwsnapshot binary", () ->

	client = null

	before (done) ->
		fixtures.app = fs.readFileSync (path.join __dirname, 'fixtures', 'app.zip')
		fixtures.snapshotSource = fs.readFileSync (path.join __dirname, 'fixtures', 'snapshot.js')
		Server.start()
		client = new Client '0.12.0', fixtures.app, fixtures.snapshotSource
		client.connect "tcp://127.0.0.1:#{Config.sockPort}", done

	after () ->
		client.disconnect()
		Server.stop()

	this.timeout(1000 * 60 * 10) # 10 minutes

	it "Should compile a valid snapshot each time (test nwsnapshotter)", (done) ->
		n = fixtures.iterations
		fails = 0
		wins = 0
		final = () ->
			wins.should.be.equal 50
			fails.should.be.equal 0
			console.log fails, wins
			done()

		client.build 1
		client.on 'fail', (err, tries) -> 
			fails++
			if --n then client.build 1 else final()
		client.on 'done', (snapshot, tries) -> 
			wins++
			if --n then client.build 1 else final()