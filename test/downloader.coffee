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

###
# Tests
###

describe "NodeWebkitDownloader", () ->

	after (done) ->
		rimraf path.join(__dirname, '..', binFolder), (err) ->
			throw err if err
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
			downloader = new Downloader '0.8.1'
			if process.platform.match(/^darwin/) 
				platform = 'osx'
			else if process.platform.match(/^win/)
				platform = 'win'
			else
				platform = 'linux'
			if platform in ['osx', 'win']
				arch = 'ia32'

			downloader.platform.should.equal platform
			downloader.arch.should.equal arch

		it 'should throw errors when supplied invalid platform or arch', () ->
			try
				downloader = new Downloader '0.8.1', 'bogusPlatform', 'bogusArch'
			catch e
				err = e
			should.exist err

		it 'should throw errors when supplied unsupported platform and arch combination', () ->
			try
				downloader = new Downloader '0.8.1', 'win', 'x64'
			catch e
				winErr = e
			try
				downloader = new Downloader '0.8.1', 'osx', 'x64'
			catch e
				osxErr = e
			should.exist winErr
			should.exist osxErr

	describe "#getDownloadURL", () ->
		it 'should return a valid download url', (done) ->
			downloader = new Downloader '0.8.1'
			url = downloader.getDownloadURL()
			require('request').head url, (err, response, body) ->
				should.not.exist err
				should.exist body
				response.statusCode.should.equal 200
				done()
			
	describe "#download", () ->
		it 'should resolve the promise when downloaded', (done) ->
			this.timeout(60000)
			downloader = new Downloader '0.8.1'
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


		it 'should resolve the promise even if the download already exists', (done) ->
			# NOTE: This is dependent on the first #download test passing
			downloader = new Downloader '0.8.1'
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

	describe "#extract", () ->
		this.timeout(600000)

		# NOTE: This is dependent on the #download tests passing
		# should probably fix this and supply archives for proper testing.
		testExtraction = (platform, arch) ->
			downloader = new Downloader '0.8.1', platform, arch
			downloader.binFolder = binFolder

			promise = downloader.download().then(downloader.extract)
			.done () ->
				downloader.verifyBinaries().should.be.true
			.fail (err) ->
				# fails the test
				throw err
			return promise

		it 'should be able to extract osx-ia32 archive', (done) -> testExtraction('osx', 'ia32').always done
		it 'should be able to extract win-ia32 archive', (done) -> testExtraction('win', 'ia32').always done
		it 'should be able to extract linux-ia32 archive', (done) -> testExtraction('linux', 'ia32').always done
		it 'should be able to extract linux-x64 archive', (done) -> testExtraction('linux', 'x64').always done

	describe "#ensure", () ->

		testEnsure = (platform, arch) ->
			downloader = new Downloader '0.8.1', platform, arch
			downloader.binFolder = binFolder
			doneCalled = false
			failCalled = false

			promise = downloader.ensure()
			.done () ->
				doneCalled = true
			.fail (err) ->
				failCalled = true
				throw err
			.always () ->
				doneCalled.should.be.true
				failCalled.should.be.false
			return promise


		it 'should be able to ensure that a specified version is available for osx-ia32', (done) -> testEnsure('osx', 'ia32').always () -> done()
		it 'should be able to ensure that a specified version is available for win-ia32', (done) -> testEnsure('win', 'ia32').always () -> done()
		it 'should be able to ensure that a specified version is available for linux-ia32', (done) -> testEnsure('linux', 'ia32').always () -> done()
		it 'should be able to ensure that a specified version is available for linux-x64', (done) -> testEnsure('linux', 'x64').always () -> done()


	describe "#cleanVersionDirectoryForPlatform", () ->
		it 'should delete the directory', (done) ->
			downloader = new Downloader '0.8.1'
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
				done()

