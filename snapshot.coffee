config = require('./config.coffee')
downloader = require('./nw-downloader.coffee')
path = require 'path'
exec = require('child_process').exec
dfd = require('jquery-deferred').Deferred
mkdirp = require('mkdirp')
rimraf = require('rimraf')

module.exports =

	prepared: false
	outputFile: 'source.bin'

	config: (obj, callback) ->
		configurationDeferred = dfd()
		unless obj.nwversion and obj.snapshotSource and obj.appSource and obj.package
			configurationDeferred.rejectWith @, new Error("Insufficient information, you must supply nwversion, snapshotSource, appSource and package.")
		unless obj.iterations?
			obj.iterations = 1
		{@nwversion, @snapshotSource, @package, @appSource, @iterations} = obj
		@prepared = false
		configurationDeferred.resolveWith @
		configurationDeferred.promise()

	prepare: () ->
		# We proxy the promise as we want to set the context, set local flags 
		# and not pass along the executables.
		preparationDeferred = dfd()
		downloadPromise = downloader.prepare @nwversion
		downloadPromise.done (@snapshotterPath, @nwPath) =>
			@prepared = true
			preparationDeferred.resolveWith @
		downloadPromise.fail () =>
			@prepared = false
			preparationDeferred.rejectWith @
		preparationDeferred.promise()

	build: () =>
		buildDeferred = dfd()
		exec "#{@snapshotterPath} --extra_code #{@snapshotSource} #{@output}", (err) ->
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
			yes
		, () ->
			# Try again and append the promise to the chain 
			if @iterations > 0 then @_build_and_test() else no
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

	notify: (id) ->
		if @id is id
			@testDeferred.resolveWith @

	make_test: () ->
		makeDeferred = dfd()
		dir = path.join __dirname, "tmp", @id
		mkdirp dir, (err) ->
			return makeDeferred.rejectWith @, err if err
			fs.writeFile path.join(dir, "package.json"), @package, (err) ->
				return makeDeferred.rejectWith @, err if err
				fs.writeFile path.join(dir, "dist.nw"), @appSource, (err) ->
					return makeDeferred.rejectWith @, err if err
					makeDeferred.resolveWith @

	cleanup_test: () ->
		cleanupDeferred = dfd()
		rimraf path.join __dirname, "tmp", @id, (err) ->
			return cleanupDeferred.rejectWith @, err if err
			cleanupDeferred.resolveWith @ 

	run: () ->

	test: () =>
		

		@testDeferred = dfd()
		@id = new Date().now() + '_' (Math.random() * (1000 - 1) + 1)
		exec "#{@nwPath} "
		setTimeout

		# TODO: Implement


	exec "#{nwsnapshot} --extra_code #{source} source.bin", (err) ->
		if err?
			console.log err
			res.end("Couldn't compile: #{err.message}", 500)
		else
			res.sendfile path.join(__dirname, 'built.bin')
