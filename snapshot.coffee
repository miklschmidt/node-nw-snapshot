###
# Dependencies
###

config = require './config.coffee'
downloader = require './nw-downloader.coffee'
path = require 'path'
exec = require('child_process').exec
dfd = require('jquery-deferred').Deferred
mkdirp = require 'mkdirp'
rimraf = require 'rimraf'
fs = require 'fs'

###
# States
###

STATE_READY = 0
STATE_CONFIGURING = 1
STATE_PREPARING = 2
STATE_BUILDING = 3
STATE_MAKINGTEST = 4
STATE_TESTING = 5
STATE_CLEANINGUP = 6

###
# Snapshot Object
###

module.exports =

	###
	# Properties
	###
	prepared: false
	outputFile: path.join __dirname, 'source.bin'
	state: STATE_READY
	execTimeout: null
	abort: no

	###
	# Configures the snapshot object for building and testing.
	#
	# @param {Object} data
	# @return {Promise}
	# @api public
	###
	config: (data, @sock, callback) ->
		@configurationDeferred = dfd()
		# Check if we're in the correct state, reject the deferred if not.
		unless @state is STATE_READY
			err = new Error("Build currently in process, please wait for it to complete, or send the 'abort' event.")
			@configurationDeferred.rejectWith @, err

		@state = STATE_CONFIGURING

		# Check if we recieved the data we need, reject the deferred if not.
		unless data.nwversion and data.snapshotSource and data.appSource and data.package
			err = new Error("Insufficient information, you must supply nwversion, snapshotSource, appSource and package.")
			@configurationDeferred.rejectWith @, err

		# Default iterations if none specified.
		unless data.iterations?
			data.iterations = 1

		# Set local properties from the data object and resolve.
		{@nwversion, @snapshotSource, @package, @appSource, @iterations} = data
		@prepared = false
		@configurationDeferred.resolveWith @
		@configurationDeferred.promise()
	
	###
	# Prepares the specified node-webkit version for compiling native snapshot.
	#
	# @return {Promise}
	# @api private
	###
	prepare: () ->
		@state = STATE_PREPARING
		@download().then(@makeTestDirectory)

	###
	# Downloads the specified node-webkit version.
	#
	# @return {Promise}
	# @api private
	###
	download: () ->
		@downloadDeferred = dfd()

		# Download the specified node-webkit distribution
		downloadPromise = downloader.fetch @nwversion

		downloadPromise.done (@snapshotterPath, @nwPath) =>
			# We proxy the promise as we want to set the context, set local flags, 
			# check if we need to abort, and not pass along the executables.
			if @checkState(@preparationDeferred, STATE_PREPARING)
				@prepared = true
				@downloadDeferred.resolveWith @

		downloadPromise.fail (err) =>
			# Download didn't go well, reset the state and reject the deferred.
			@resetState()
			@downloadDeferred.rejectWith @, err

		@downloadDeferred.promise()

	###
	# Creates the test directory with application files.
	#
	# @return {Promise}
	# @api private
	###
	makeTestDirectory: () ->
		@makeDeferred = dfd()
		@state = STATE_MAKINGTEST
		@testdir = path.join __dirname, "tmp", new Date().now()

		# Make sure the testdir exists
		mkdirp @testdir, (err) ->
			return if @checkState(@makeDeferred, STATE_MAKINGTEST, err)

			# Modify the package.json to use our snapshot			
			package = JSON.parse @package.toString()
			package.snapshot = path.basename @outputFile
			package = JSON.stringify package

			# Write package.json
			fs.writeFile path.join(@testdir, "package.json"), package, (err) ->
				return if @checkState(@makeDeferred, STATE_MAKINGTEST, err)

				# Write dist.nw
				fs.writeFile path.join(@testdir, "dist.nw"), @appSource, (err) ->
					return if @checkState(@makeDeferred, STATE_MAKINGTEST, err)
					@makeDeferred.resolveWith @, @testdir

		@makeDeferred.promise()
	
	###
	# Compiles the snapshot.
	#
	# @return {Promise}
	# @api private
	###
	compile: () =>
		@state = STATE_BUILDING
		@buildDeferred = dfd()

		# Compile the snapshot
		exec "#{@snapshotterPath} --extra_code #{@snapshotSource} #{@outputFile}", (err) ->
			if @checkState(@buildDeferred, STATE_BUILDING, err)
				# Copy the snapshot to the test dir
				fs.writefileSync path.join(@testdir, path.basename(@outputFile)), fs.readFileSync @outputFile
				# Resolve the deferred, we're done.
				@buildDeferred.resolveWith @

		@buildDeferred.promise()

	###
	# Starts an iteration which will compile and test the snapshot.
	#
	# @return {Promise}
	# @api private
	###
	iterate: () ->
		@iterations--
		@compile().then(@test)

	###
	# Starts the snapshotter.
	#
	# @return {Promise}
	# @api public
	###
	run: () ->
		@tries = 0
		@runDeferred = dfd()

		# Start compilating and testing.
		@iterate().then(() ->
			# Nothing to do here. Snapshot is good so return true.
			yes

		, (err) ->
			# Notify about the failure
			@tries++
			@runDeferred.notifyWith @, err, @tries
			# Delete old snapshot
			fs.unlinkSync path.join(@testdir, path.basename(@outputFile))
			# Try again and append the promise to the chain or fail if iterations are used up.
			if @iterations > 0 then @iterate() else no

		).done(() ->
			# Snapshot test passed, clean up!
			@cleanupTest.always () ->
				# Read the snapshot into a buffer
				fileBuffer = fs.readFileSync(@outputFile)
				# Clean up the snapshot
				@cleanupSnapshot()
				# Resolve the deferred, we were succesful!
				@runDeferred.resolveWith @, fileBuffer, @tries
				# Finally reset the state for the next job.
				@resetState()

		).fail (err) ->
			# Snapshot testing failed, clean up!
			@cleanupTest.always () ->
				@cleanupSnapshot()
				@runDeferred.rejectWith @, new Error("Couldn't verify snapshot: " + err?.message), @tries
				@resetState()

		@runDeferred.promise()

	###
	# Checks if the snapshotter is in the correct state or if we need to abort.
	# An error object can be supplied for convenience when checking in callbacks.
	#
	# @return {Boolean}
	# @api private
	###
	checkState: (deferred, expectedState, err = false) ->
		if err
			deferred.rejectWith @, err
			return false
		if @state isnt expectedState
			err = new Error("State mismatch. State was #{@state} expecting #{expectedState}.")
			deferred.rejectWith @, err
			return false
		if @abort
			# If we need to abort we just reject the deferred so 
			# everything will happen naturally.
			deferred.rejectWith @, new Error('Aborted!')
			return false
		return true

	###
	# Cleans up (deletes) the test directory.
	#
	# @return {Promise}
	# @api private
	###
	cleanupTest: () ->
		@state = STATE_CLEANINGUP
		@cleanupDeferred = dfd()

		# Delete the test directory and all it's content.
		rimraf @testdir, (err) ->
			return if @cleanupDeferred.rejectWith @, err if err
			@cleanupDeferred.resolveWith @ 
		
		@cleanupDeferred.promise()

	###
	# Cleans up (deletes) the compiled snapshot.
	#
	# @return {Boolean} result of unlink.
	# @api private
	###
	cleanupSnapshot: () ->
		fs.unlinkSync @outputFile

	###
	# Notifies the snapshotter when the app has launced succesfully.
	# This method should be called from the server when the callback URL is requested.
	# Calling this method will immediately kill the app, as it's no longer needed.
	#
	# @return {Boolean} always true. 
	# @api public
	###
	notify: (id) ->
		if @id is id
			@didNotify = yes
			@process.kill()
		true

	###
	# Launces the app with the compiled snapshot.
	#
	# @return {Promise}
	# @api private
	###
	launch: () ->
		@state = STATE_TESTING
		@launchDeferred = dfd()
		@didNotify = false

		# Make an id to make sure we're called back from the right application
		# and not some random resurrected zombie node-webkit process from a previous test
		@id = new Date().now() + '_' (Math.random() * (1000 - 1) + 1)

		# Execute the application 
		@process = exec """#{@nwPath} --buildcallback "#{config.callbackURL}/#{@id}" #{@testdir}"""

		# Set a timeout, we don't want to wait for the application forever.
		@execTimeout = setTimeout () ->
			@process.kill()
			@launchDeferred.rejectWith @, new Error("Timeout in testing after #{config.timeout}ms.")
		, config.timeout

		# When the process exits, check if we we're called back
		@process.on 'exit', () ->
			if @didNotify
				@launchDeferred.resolveWith @
				@didNotify = false
			else
				clearTimeout @execTimeout
				@launchDeferred.rejectWith @, new Error("Process exited without calling back.")

		@launchDeferred.promise()

	###
	# Tests the compiled snapshot.
	#
	# @return {Promise}
	# @api private
	###
	test: () ->
		@testDeferred = dfd()
		@launch().fail((err) ->
			# Testing failed, clean up the snapshot so somebody doesn't 
			# accidentally use it some where.
			@cleanupSnapshot()
			@testDeferred.rejectWith @, err
		).done () ->
			# Testing succeeded.
			@testDeferred.resolveWith @
		@testDeferred.promise()

	###
	# Resets the snapshotter object's state.
	#
	# @return {Boolean} always true
	# @api private
	###
	resetState: () ->
		@abort = no
		@prepared = false
		@state = STATE_READY
		true

	###
	# Calls resetState and resolves the abortDeferred.
	#
	# @return {Deferred}
	# @api private
	###
	resetStateAndResolve: () ->
		@resetState()
		@abortDeferred.resolveWith @

	###
	# Aborts current process, and properly cleans up.
	# This method is called from the server when an 'abort' event is recieved.
	#
	# @return {Promise}
	# @api public
	###
	abort: () ->
		@abortDeferred = dfd()
		@abort = yes
		# The deferreds will fail once an async method is completed because of @abort.
		switch @state
			when STATE_READY then @resetStateAndResolve()
			when STATE_CONFIGURING then @configurationDeferred.always @resetStateAndResolve
			when STATE_PREPARING then @preparationDeferred.always @resetStateAndResolve
			when STATE_BUILDING @buildDeferred.always @resetStateAndResolve
			when STATE_MAKINGTEST then @makeDeferred.always @resetStateAndResolve
			when STATE_TESTING
				@launchDeferred.always @resetStateAndResolve
				# Kill the app to speed the process along.
				@process.kill()
				
		@abortDeferred.promise()
