###
# Dependencies
###

should       = require 'should'
{Downloader} = require '../index'
rimraf       = require 'rimraf'
fs           = require 'fs'
path         = require 'path'

###
# Fixtures
###

binFolder    = 'test_bin'
{nwVersion}    = require './config'

###
# Tests
###

describe "NodeWebkitDownloader", () ->

	after (done) ->
		rimraf path.join(__dirname, '..', binFolder), (err) ->
			# See https://github.com/miklschmidt/node-nw-snapshot/issues/1
			if err and process.platform.match(/^win/)
				return done() # Yea... well.. it doesn't work here..
			else if err 
				throw err
			done()

	before (done) ->
		if fs.existsSync(path.join __dirname, '..', binFolder)
			rimraf path.join(__dirname, '..', binFolder), (err) ->
				throw err if err
				done()
		else
			done()

	describe "#constructor", () ->
		it 'should throw errors when version is undefined', () ->
			try
				downloader = new Downloader
			catch e
				err = e
			should.exist err

		it 'should properly set platform and arch without parameters', () ->
			downloader = new Downloader nwVersion
			if process.platform.match(/^darwin/) 
				platform = 'osx'
			else if process.platform.match(/^win/)
				platform = 'win'
			else
				platform = 'linux'

			arch = process.arch

			downloader.platform.should.equal platform
			downloader.arch.should.equal arch

		it 'should throw errors when supplied invalid platform or arch', () ->
			try
				downloader = new Downloader nwVersion, 'bogusPlatform', 'bogusArch'
			catch e
				err = e
			should.exist err

		# Conditional test.. probably not the best way to handle this..
		if process.platform.match(/^win/)
			it 'should throw errors when supplying linux as platform on windows', () ->
				try
					downloader = new Downloader nwVersion, 'linux', 'x64'
				catch e
					x64error = e
				try
					downloader = new Downloader nwVersion, 'linux', 'ia32'
				catch e
					ia32error = e
				should.exist x64error
				should.exist ia32error

	describe "#getDownloadURL", () ->
		it 'should return a valid download url', (done) ->
			downloader = new Downloader nwVersion
			url = downloader.getDownloadURL()
			require('request').head url, (err, response, body) ->
				should.not.exist err
				should.exist body
				response.statusCode.should.equal 200
				done()
			return null

		it 'should return a valid minimal download url', (done) ->
			downloader = new Downloader nwVersion, undefined, undefined, true
			url = downloader.getDownloadURL()
			require('request').head url, (err, response, body) ->
				should.not.exist err
				should.exist body
				response.statusCode.should.equal 200
				done()
			return null
			
	describe "#download", () ->
		it 'should resolve the promise when downloaded', (done) ->
			this.timeout(60000)
			downloader = new Downloader nwVersion
			downloader.binFolder = binFolder

			doneCalled = false
			failCalled = false
			downloader.download()
			.done () -> doneCalled = true
			.fail () -> failCalled = true
			.always () -> 
				doneCalled.should.be.true
				failCalled.should.be.false
				done()
			return null

		it 'should be able to download minimal distribution', () ->
			this.timeout(60000)
			downloader = new Downloader nwVersion, undefined, undefined, true
			downloader.binFolder = binFolder
			downloader.download()

		it 'should reject the promise when download failed', (done) ->
			downloader = new Downloader '9999.99999.9999' # useless version number to force a fail.
			downloader.binFolder = binFolder
			doneCalled = false
			failCalled = false
			downloader.download()
			.done () -> doneCalled = true
			.fail () -> failCalled = true
			.always () -> 
				doneCalled.should.be.false
				failCalled.should.be.true
				# Remove the bogus directory created with the crazy version number
				rimraf downloader.getLocalPath(), (err) ->
					done()
			return null


		it 'should resolve the promise even if the download already exists', (done) ->
			# NOTE: This is dependent on the first #download test passing
			downloader = new Downloader nwVersion
			downloader.binFolder = binFolder
			doneCalled = false
			failCalled = false
			downloader.download()
			.done () -> doneCalled = true
			.fail () -> failCalled = true
			.always () -> 
				doneCalled.should.be.true
				failCalled.should.be.false
				done()
			return null

	describe "#extract", () ->
		this.timeout(60000)

		# NOTE: This is dependent on the #download tests passing
		# should probably fix this and supply archives for proper testing.
		testExtraction = (platform, arch) ->
			downloader = new Downloader nwVersion, platform, arch
			downloader.binFolder = binFolder

			promise = downloader.download().then((destinationFile) => return downloader.extract(destinationFile))
			.done () ->
				downloader.verifyBinaries().should.be.true
			.fail (err) ->
				# fails the test
				throw err
			return promise

		it 'should be able to extract osx-x64 archive', () -> testExtraction('osx', 'x64')
		it 'should be able to extract win-ia32 archive', () -> testExtraction('win', 'ia32')

		# Conditional test.. probably not the best way to handle this..
		unless process.platform.match(/^win/)
			it 'should be able to extract linux-ia32 archive', () -> testExtraction('linux', 'ia32')
			it 'should be able to extract linux-x64 archive', () -> testExtraction('linux', 'x64')

	describe "#ensure", () ->
		this.timeout(60000)
		testEnsure = (platform, arch) ->
			downloader = new Downloader nwVersion, platform, arch
			downloader.binFolder = binFolder

			return downloader.ensure()


		it 'should be able to ensure that a specified version is available for osx-ia32', () -> testEnsure('osx', 'x64')
		it 'should be able to ensure that a specified version is available for win-ia32', () -> testEnsure('win', 'ia32')
		# Conditional test.. probably not the best way to handle this..
		unless process.platform.match(/^win/)
			it 'should be able to ensure that a specified version is available for linux-ia32', () -> testEnsure('linux', 'ia32')
			it 'should be able to ensure that a specified version is available for linux-x64', () -> testEnsure('linux', 'x64')

		it 'should be able to ensure minimal distribution', () ->
			downloader = new Downloader nwVersion, undefined, undefined, true
			downloader.binFolder = binFolder
			downloader.ensure()


	describe "#cleanVersionDirectoryForPlatform", () ->
		it 'should delete the directory', () ->
			downloader = new Downloader nwVersion
			downloader.binFolder = binFolder
			doneCalled = false
			failCalled = false

			fs.existsSync(downloader.getLocalPath()).should.be.true

			promise = downloader.cleanVersionDirectoryForPlatform()
			.done () ->
				doneCalled = true
			.fail (err) ->
				failCalled = true
				throw err
			.always () ->
				doneCalled.should.be.true
				failCalled.should.be.false
				fs.existsSync(downloader.getLocalPath()).should.be.false

