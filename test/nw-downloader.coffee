should = require 'should'
NodeWebkitDownloader = require '../nw-downloader.coffee'
describe "NodeWebkitDownloader", () ->
	describe "#constructor", () ->
		it 'should properly set platform and arch without parameters', () ->
			downloader = new NodeWebkitDownloader '0.8.1'
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
				downloader = new NodeWebkitDownloader '0.8.1', 'bogusPlatform', 'bogusArch'
			catch e
				err = e
			should.exist err

		it 'should throw errors when supplied unsupported platform and arch combination', () ->
			try
				downloader = new NodeWebkitDownloader '0.8.1', 'win', 'x64'
			catch e
				winErr = e
			try
				downloader = new NodeWebkitDownloader '0.8.1', 'osx', 'x64'
			catch e
				osxErr = e
			should.exist winErr
			should.exist osxErr

	describe "#getDownloadURL", () ->
		it 'should return a valid download url', (done) ->
			downloader = new NodeWebkitDownloader '0.8.1'
			url = downloader.getDownloadURL()
			require('request').head url, (err, response, body) ->
				should.not.exist err
				should.exist body
				response.statusCode.should.equal 200
				done()
			
	describe "#download", () ->
		this.timeout(60000)
		it 'should resolve the promise when downloaded', (done) ->
			downloader = new NodeWebkitDownloader '0.8.1'
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
			downloader = new NodeWebkitDownloader '9999.99999.9999' # useless version number to force a fail.
			doneCalled = false
			failCalled = false
			downloader.download()
			.done () -> doneCalled = true
			.fail () -> failCalled = true
			.always () -> 
				doneCalled.should.be.false
				failCalled.should.be.true
				done()
