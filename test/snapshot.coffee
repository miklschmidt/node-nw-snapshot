###
# Dependencies
###

should     = require 'should'
{Snapshot, Config} = require '../index'
rimraf     = require 'rimraf'
fs         = require 'fs'
path       = require 'path'

{nwVersion}    = require './config'

###
# Fixtures
###

fixtures =
	app: null
	snapshotSource: null
	iterations: 5

###
# Tests
###

# TODO: Add test for snapshot callback url!

describe "Snapshot", () ->

	before () ->
		fixtures.app = fs.readFileSync (path.join __dirname, 'fixtures', 'app.zip'), 'binary'
		fixtures.snapshotSource = fs.readFileSync (path.join __dirname, 'fixtures', 'snapshot.js')

	describe "#constructor", () ->

		it 'should reject the deferred when data is missing', (done) ->
			failCalled = false
			doneCalled = false
			Snapshot.config {}
			.fail () ->
				failCalled = true
			.done () ->
				doneCalled = true
			.always () ->
				failCalled.should.be.true
				doneCalled.should.be.false
				done()

		it 'should resolve the deferred when configured correctly', (done) ->
			failCalled = false
			doneCalled = false
			Snapshot.config
				nwVersion: nwVersion
				appSourceNw: fixtures.app
				snapshotSource: fixtures.snapshotSource
				iterations: fixtures.iterations

			.fail (err) ->
				throw err
				failCalled = true
			.done () ->
				doneCalled = true
			.always () ->
				failCalled.should.be.false
				doneCalled.should.be.true
				Snapshot.prepared.should.be.false
				done()

	describe "#prepare", () ->

		it 'should resolve the deferred', () ->
			this.timeout(60000)
			doneCalled = false
			failCalled = false
			Snapshot.prepare()
			.fail (err) ->
				throw err
				failCalled = true
			.done () ->
				doneCalled = true
			.always () ->
				failCalled.should.be.false
				doneCalled.should.be.true

		it 'should make test directory, and extract the source', () ->
			Snapshot.testdir.should.exist
			fs.existsSync(Snapshot.testdir).should.be.true

		it 'should extract the source', () ->
			fs.existsSync(path.join Snapshot.testdir, 'src').should.be.true
			fs.existsSync(path.join Snapshot.testdir, 'src', 'package.json').should.be.true

		it 'should write the snapshot path to package.json', () ->
			Snapshot.outputFileName.should.exist
			packagePath = path.join Snapshot.testdir, 'src', 'package.json'
			packageJson = JSON.parse fs.readFileSync packagePath
			packageJson.snapshot.should.equal Snapshot.outputFileName

		it 'should have the node-webkit executables handy', () ->
			fs.existsSync(Snapshot.snapshotterPath).should.be.true
			fs.existsSync(Snapshot.nwPath).should.be.true

	describe "#compile", () ->
		it 'should resolve the deferred', () ->
			Snapshot.compile()
		
		it 'should generate a test id', () ->
			Snapshot.id.should.exist

		it 'should write snapshot.js to test dir', () ->
			fs.existsSync(path.join(Snapshot.testdir, 'snapshot.js')).should.be.true

		it 'should generate the snapshot', () ->
			Snapshot.outputFilePath.should.exist
			fs.existsSync(Snapshot.outputFilePath).should.be.true

		it 'should copy the snapshot to the test directory', () ->
			Snapshot.testFilePath.should.exist
			fs.existsSync(Snapshot.testFilePath).should.be.true

	describe "#launch", () ->

		it 'should resolve when called back', (done) ->

			doneCalled = false
			failCalled = false

			Snapshot.launch()
			.done () -> doneCalled = true
			.fail () -> failCalled = true
			.always () -> 
				doneCalled.should.be.true
				failCalled.should.be.false
				done()

			Snapshot.process.should.exist
			# Should kill the process immediately and resolve
			Snapshot.notify Snapshot.id

		it 'should reject if not called back', (done) ->
			
			doneCalled = false
			failCalled = false

			Snapshot.launch()
			.done () -> doneCalled = true
			.fail () -> failCalled = true
			.always () -> 
				doneCalled.should.be.false
				failCalled.should.be.true
				done()

			Snapshot.process.should.exist
			Snapshot.process.kill()

		it 'should timeout if nothing happens', (done) ->
			# Set the timeout to be ridiculously low, so we fail pretty much instantly.
			oldTimeout = Config.timeout
			Config.timeout = 1

			doneCalled = false
			failCalled = false

			Snapshot.launch()
			.done () -> doneCalled = true
			.fail () -> failCalled = true
			.always () -> 
				doneCalled.should.be.false
				failCalled.should.be.true
				done()

			# Put the original timeout back
			Config.timeout = oldTimeout
			Snapshot.process.should.exist

	describe "#test", () ->

		it 'should clean up snapshot when failed', (done) ->
			# Set the timeout to be ridiculously low, so we fail pretty much instantly.
			oldTimeout = Config.timeout
			Config.timeout = 1

			doneCalled = false
			failCalled = false

			Snapshot.test()
			.done () -> doneCalled = true
			.fail () -> failCalled = true
			.always () -> 
				doneCalled.should.be.false
				failCalled.should.be.true
				fs.existsSync(Snapshot.outputFilePath).should.be.false

				# Put the original timeout back
				Config.timeout = oldTimeout
				Snapshot.process.should.exist
				done()
			return null


	describe "#run", () ->

		it "should iterate and notify", (done) ->
			this.timeout(10000)
			# Set the timeout to be ridiculously low, so we fail pretty much instantly.
			oldTimeout = Config.timeout
			Config.timeout = 1

			doneCalled = false
			failCalled = false

			notifications = 0
			Snapshot.run()
			.progress (err, tries) ->
				notifications++
			.done () ->
				doneCalled = true
			.fail () ->
				failCalled = true
			.always () ->	
				notifications.should.equal fixtures.iterations
				doneCalled.should.be.false
				failCalled.should.be.true

				# Put the original timeout back
				Config.timeout = oldTimeout
				done()
			return null

		it "should reject the deferred when not prepared/state mismatch", (done) ->
			doneCalled = false
			failCalled = false

			Snapshot.prepared.should.be.false

			Snapshot.run()
			.done () ->
				doneCalled = true
			.fail (err) ->
				failCalled = true
			.always () ->	
				doneCalled.should.be.false
				failCalled.should.be.true
				done();
			return null

		it "should resolve with snapshot when succesful", () ->
			doneCalled = false
			failCalled = false

			oldLaunch = Snapshot.launch

			# Mock the launch function and notify immediately
			Snapshot.launch = () ->
				result = oldLaunch.apply Snapshot, arguments
				Snapshot.notify Snapshot.id
				return result
			# Prepare the snapshotter
			Snapshot.prepare()
			# RUN!
			.then Snapshot.run
			.done () ->
				doneCalled = true
			.fail (err) ->
				throw err
				failCalled = true
			.always () ->	
				doneCalled.should.be.true
				failCalled.should.be.false

				# Put the original launch function back
				Snapshot.launch = oldLaunch
