config = require('./config.coffee')
downloader = require('./nw-downloader.coffee')
path = require 'path'
exec = require('child_process').exec
dfd = require('jquery-deferred').Deferred

module.exports =

	prepared: false
	outputFile: 'source.bin'

	config: (obj, callback) ->
		configurationDeferred = dfd()
		unless obj.nwversion and obj.snapshotSource and obj.appSource and obj.package
			configurationDeferred.rejectWith @, new Error("Insufficient information, you must supply nwversion, source and package.")
		unless obj.iterations?
			obj.iterations = 1
		{@nwversion, @snapshotSource, @package, @appSource, @iterations} = obj
		@prepared = false
		configurationDeferred.resolveWith @
		configurationDeferred.promise()

	prepare: () ->
		# We proxy the promise as we want to set the context, set local flags 
		# and not pass along the executable.
		preparationDeferred = dfd()
		downloadPromise = downloader.prepare @nwversion
		downloadPromise.done (@executable) =>
			@prepared = true
			preparationDeferred.resolveWith @
		downloadPromise.fail () =>
			@prepared = false
			preparationDeferred.rejectWith @
		preparationDeferred.promise()

	build: () =>
		buildDeferred = dfd()
		exec "#{@executable} --extra_code #{@snapshotSource} #{@output}", (err) ->
			return buildDeferred.rejectWith @, err if err
			buildDeferred.resolveWith @
		return buildDeferred.promise()


	_build_and_test: () ->
		@iterations--
		@build().then(@test)

	build_and_test: () ->
		@tries = 0
		buildDeferred = dfd()
		@_build_and_test().then(() ->
			# Nothing to do here
		, () ->
			# Try again and append the promise to the chain 
			@_build_and_test() if @iterations > 0
		).progress( () ->
			@tries++
			buildDeferred.notifyWith @, @tries
		).done () ->
			buildDeferred.resolveWith @, fs.readFileSync(@outputFile)
		).fail () ->
			buildDeferred.rejectWith @, null
		buildDeferred.promise()

	make_snapshot: () ->
		@tries = 0

	test: () =>
		# TODO: Implement


	exec "#{nwsnapshot} --extra_code #{source} source.bin", (err) ->
		if err?
			console.log err
			res.end("Couldn't compile: #{err.message}", 500)
		else
			res.sendfile path.join(__dirname, 'built.bin')
