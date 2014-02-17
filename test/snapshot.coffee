should = require 'should'
Snapshot = require '../snapshot.coffee'
rimraf = require 'rimraf'
fs = require 'fs'
path = require 'path'

fixtures =
	app: null
	snapshotSource: null

before () ->
	fixtures.app = fs.readFileSync (path.join __dirname, 'fixtures', 'app.zip'), 'binary'
	fixtures.snapshotSource = fs.readFileSync (path.join __dirname, 'fixtures', 'snapshot.js')

describe "Snapshot", () ->
	
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
			Snapshot.config nwVersion: '0.8.1', appSourceNw: fixtures.app, snapshotSource: fixtures.snapshotSource
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
		it 'should make test directory and extract the source', (done) ->
			this.timeout(60000)
			Snapshot.prepare()
			.fail (err) ->
				throw err
			.done () ->
				Snapshot.testdir.should.exist
				fs.existsSync(Snapshot.testdir).should.be.true
				fs.existsSync(path.join Snapshot.testdir, 'src').should.be.true
				fs.existsSync(path.join Snapshot.testdir, 'src', 'package.json').should.be.true
			.always () ->
				done()

	describe "#prepare", () ->
		it 'should make test directory and extract the source', (done) ->
			this.timeout(60000)
			Snapshot.prepare()
			.fail (err) ->
				throw err
			.done () ->
				Snapshot.testdir.should.exist
				fs.existsSync(Snapshot.testdir).should.be.true
				fs.existsSync(path.join Snapshot.testdir, 'src').should.be.true
				fs.existsSync(path.join Snapshot.testdir, 'src', 'package.json').should.be.true
			.always () ->
				done()