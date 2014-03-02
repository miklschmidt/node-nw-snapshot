###
# Dependencies
###

Config     = require './config'
Downloader = require './downloader'
Utils      = require './utils'
path       = require 'path'
exec       = require('child_process').exec
dfd        = require('jquery-deferred').Deferred
mkdirp     = require 'mkdirp'
rimraf     = require 'rimraf'
fs         = require 'fs'
glob       = require 'glob'

###
# States
###

STATE_READY                 = 0
STATE_CONFIGURING           = 1
STATE_PREPARING             = 2
STATE_BUILDING              = 3
STATE_MAKINGTEST            = 4
STATE_TESTING               = 5
STATE_CLEANINGUP            = 6

###
# Snapshot definition
###

module.exports =

	###
	# Properties
	###
	prepared: false
	state: STATE_READY
	outputFileName: 'snapshot.bin'
	outputFilePath: null
	execTimeout: null
	aborted: no
	tries: 0

	###
	# Configures the snapshot object for building and testing.
	# NOTE: data.appSourceNw is a zip archive containing all files needed 
	# to run the app (usually called app.nw). That is all assets and package.json.
	#
	# @param {Object} data
	# @returns {Promise}
	# @api public
	###
	config: (data) ->
		@configurationDeferred = dfd()
		# Check if we're in the correct state, reject the deferred if not.
		unless @state is STATE_READY
			err = new Error("Build currently in process, please wait for it to complete, or send the 'abort' event.")
			@configurationDeferred.rejectWith @, [err]

		@state = STATE_CONFIGURING

		# Check if we recieved the data we need, reject the deferred if not.
		unless data.nwVersion and data.snapshotSource and data.appSourceNw
			err = new Error("Insufficient information, you must supply nwVersion, snapshotSource, appSourceNw.")
			@resetState()
			@configurationDeferred.rejectWith @, [err]

		# Default iterations if none specified.
		unless data.iterations?
			data.iterations = 1

		# Set local properties from the data object and resolve.
		{@nwVersion, @snapshotSource, @appSourceNw, @iterations} = data
		@prepared = false
		@configurationDeferred.resolveWith @
		@configurationDeferred.promise()
	
	###
	# Prepares the specified node-webkit version for compiling the snapshot.
	#
	# @returns {Promise}
	# @api private
	###
	prepare: () ->
		@state = STATE_PREPARING
		@preparationDeferred = dfd()
		@download()
		.then(@makeTestDirectory)
		.then(@extractSource)
		.done () ->
			@preparationDeferred.resolveWith @
		.fail (err) ->
			@preparationDeferred.rejectWith @, [err, @tries]
		@preparationDeferred.promise()

	###
	# Extracts the application source code to the test directory, and
	# patches the package.json file to make use of the snapshot.
	#
	# @returns {Promise}
	# @api private
	###
	extractSource: () ->
		@state = STATE_PREPARING
		@extractDeferred = dfd()
		mkdirp path.join(@testdir, 'src'), (err) =>
			zipLocation = path.join(@testdir, 'src', 'app.zip')
			fs.writeFile zipLocation, @appSourceNw, 'binary', (err) =>
				return unless @checkState @extractDeferred, STATE_PREPARING, err
				Utils.unzip zipLocation, path.join(@testdir, 'src')
				.done () =>
					# Write snapshot information to package.json
					packagePath = path.join @testdir, 'src', 'package.json'
					packageJson = JSON.parse fs.readFileSync packagePath
					packageJson.snapshot = @outputFileName
					fs.writeFile packagePath, JSON.stringify(packageJson), (err) =>
						return unless @checkState @extractDeferred, STATE_PREPARING, err
						@extractDeferred.resolveWith @
				.fail (err) =>
					@extractDeferred.rejectWith @, [err]
		@extractDeferred.promise()

	###
	# Downloads the specified node-webkit version.
	#
	# @returns {Promise}
	# @api private
	###
	download: () ->
		@downloadDeferred = dfd()

		# Download the specified node-webkit distribution
		downloader = new Downloader(@nwVersion)
		downloadPromise = downloader.ensure()

		downloadPromise.done (@snapshotterPath, @nwPath) =>
			# We proxy the promise as we want to set the context, set local flags, 
			# check if we need to abort, and not pass along the executables.
			if @checkState(@preparationDeferred, STATE_PREPARING)
				@prepared = true
				@downloadDeferred.resolveWith @

		downloadPromise.fail (err) =>
			# Download didn't go well, reset the state and reject the deferred.
			@resetState()
			@downloadDeferred.rejectWith @, [err]

		@downloadDeferred.promise()

	###
	# Creates the test directory with application files.
	#
	# @returns {Promise}
	# @api private
	###
	makeTestDirectory: () ->
		@makeDeferred = dfd()
		@state = STATE_MAKINGTEST
		@testdir = path.join __dirname, '..', "tmp", new Date().getTime() + ""

		# Make sure the testdir exists
		mkdirp @testdir, (err) =>
			return unless @checkState(@makeDeferred, STATE_MAKINGTEST, err)
			@makeDeferred.resolveWith @,[ @testdir]

		@makeDeferred.promise()

	###
	# Patches the snapshot source code with the build callback function.
	# The callback function is supposed to be invoked from the main .html file.
	# This is done to test the validity of the snapshot, to make sure it works.
	#
	# @returns {Promise}
	# @api private
	###
	patchSource: () ->
		@patchDeferred = dfd()
		@state = STATE_BUILDING

		# Make an id to make sure we're called back from the right application
		# and not some random resurrected zombie node-webkit process from a previous test.
		# The id is used as a flag for launching the app, so that u need the build id to trigger
		# the build callback.
		@id = new Date().getTime() + '_' + Math.round(Math.random() * (1000 - 1) + 1)

		# Generate callback code
		callbackCode = """
			// callback for build testing
			var __buildcallbackWrapper = function() {
				callbackArgIndex = require('nw.gui').App.argv.indexOf('--#{@id}');
				if (callbackArgIndex > -1) {
					url = "#{Config.callbackURL}/#{@id}"
					script = document.createElement('script');
					script.src = url;
					script.onload = function(){
						process.exit();
					};
					document.querySelector('body').appendChild(script);
				}
			}
		"""
		# Write snapshot js with appended callback code
		fs.writeFile path.join(@testdir, 'snapshot.js'), @snapshotSource.toString() + callbackCode, (err) =>
			return unless @checkState @patchDeferred, STATE_BUILDING, err
			@patchDeferred.resolveWith @

		@patchDeferred.promise()
	
	###
	# Compiles the snapshot.
	#
	# @returns {Promise}
	# @api private
	###
	compile: () ->
		@state = STATE_BUILDING
		@buildDeferred = dfd()

		@outputFilePath = path.join @testdir, @outputFileName
		@testFilePath = path.join(@testdir, 'src', path.basename @outputFileName)

		# Compile the snapshot
		@patchSource()
		.done () ->
			exec "#{@snapshotterPath} --extra_code #{path.join @testdir, 'snapshot.js'} #{@outputFilePath}", (err) =>
				if @checkState(@buildDeferred, STATE_BUILDING, err)
					# Copy the snapshot to the test dir
					fs.readFile @outputFilePath, 'binary', (err, data) =>
						return unless @checkState(@buildDeferred, STATE_BUILDING, err)
						fs.writeFile @testFilePath, data, 'binary', (err) =>
							return unless @checkState(@buildDeferred, STATE_BUILDING, err)
							# Resolve the deferred, we're done.
							@buildDeferred.resolveWith @
		.fail (err) ->
			@buildDeferred.rejectWith @, [err]


		@buildDeferred.promise()

	###
	# Starts an iteration which will compile and test the snapshot.
	#
	# @returns {Promise}
	# @api private
	###
	iterate: () ->
		@iterations--
		@compile().then @test

	###
	# Starts the snapshotter.
	#
	# @returns {Promise}
	# @api public
	###
	run: () ->
		@tries = 0
		@runDeferred = dfd()

		unless @prepared
			@runDeferred.rejectWith @, [new Error("You need to run prepare() first!")]
			return @runDeferred.promise()

		doneFilter = () ->
				# Nothing to do here. Snapshot is good.

		failFilter = (err) ->
				# Notify about the failure
				@tries++
				@runDeferred.notifyWith @, [err, @tries]
				# Delete old snapshot
				@cleanupSnapshot()
				# Try again and append the promise to the chain or fail if iterations are used up.
				if @iterations > 0 then @iterate().then.apply(@, filters) else err

		filters = [doneFilter, failFilter]

		# Start compilating and testing.
		@iterate().then.apply @, filters

		.done () ->
			# Snapshot test passed, clean up!
			# Read the snapshot into a buffer
			fileBuffer = fs.readFileSync @outputFilePath
			@cleanupTest().always () ->
				# Resolve the deferred, we were succesful!
				@runDeferred.resolveWith @, [fileBuffer, @tries]
				# Finally reset the state for the next job.
				@resetState()

		.fail (err) ->
			# Snapshot testing failed, clean up!
			@cleanupTest().always () ->
				@runDeferred.rejectWith @, [err, @tries]
				@resetState()

		@runDeferred.promise()

	###
	# Checks if the snapshotter is in the correct state or if we need to abort.
	# An error object can be supplied for convenience when checking in callbacks.
	#
	# @param {Deferred} deferred.
	# @param {Integer} expectedState
	# @param {Error} err 
	# @returns {Boolean}
	# @api private
	###
	checkState: (deferred, expectedState, err = null) ->
		if err
			deferred.rejectWith @, [err]
			return false
		if @state isnt expectedState
			err = new Error("State mismatch. State was #{@state} expecting #{expectedState}.")
			deferred.rejectWith @, [err]
			return false
		if @aborted
			# If we need to abort we just reject the deferred so 
			# everything will happen naturally.
			deferred.rejectWith @, [new Error('Aborted!')]
			return false
		return true

	###
	# Cleans up (deletes) the test directory.
	#
	# @returns {Promise}
	# @api private
	###
	cleanupTest: () ->
		@state = STATE_CLEANINGUP
		@cleanupDeferred = dfd()

		# Delete the test directory and all its content.
		rimraf @testdir, (err) =>
			return @cleanupDeferred.rejectWith @, [err] if err

			glob "**/*v8.log", (err, files) =>
				return @cleanupDeferred.rejectWith @, [err] if err
				for file in files
					try
						fs.unlinkSync file
					catch e
						return @cleanupDeferred.rejectWith @, [e]
				@cleanupDeferred.resolveWith @

		@cleanupDeferred.promise()

	###
	# Cleans up (deletes) the compiled snapshot.
	#
	# @returns {Boolean} result of unlink.
	# @api private
	###
	cleanupSnapshot: () ->
		fs.unlinkSync @outputFilePath if fs.existsSync @outputFilePath

	###
	# Notifies the snapshotter when the app has launced succesfully.
	# This method should be called from the server when the callback URL is requested.
	# Calling this method will immediately kill the app, as it's no longer needed.
	#
	# @returns {Boolean} always true. 
	# @api public
	###
	notify: (id) ->
		if @id is id
			@didNotify = yes
			@killProcess()
		true

	killProcess: () ->
		if Config.platform is 'win'
			# It seems impossible to kill nw.exe processes on windows.
			# Hit it with all we've got!
			# youtube.com/watch?v=74BzSTQCI_c
			exec "taskkill /pid #{@process.pid} /f"
			try
				@process.kill('SIGKILL')
				@process.kill('SIGTERM')
				@process.kill('SIGHUP')
				@process.kill()
				@process.exit()
			catch
		else
			@process.kill()

	###
	# Launces the app with the compiled snapshot. 
	# NOTE: patchSource/compile has to be run first to generate an id and callback code.
	#
	# @returns {Promise}
	# @api private
	###
	launch: () ->
		@state = STATE_TESTING
		@launchDeferred = dfd()
		@didNotify = false

		unless @id
			@launchDeferred.rejectWith @, [new Error("Can't launch the test without a test id. See @compile() and @patchSource().")]

		# Execute the application 
		exePath = path.join @testdir, 'src'
		@process = exec """#{@nwPath} "--#{@id}" #{exePath}"""

		# Set a timeout, we don't want to wait for the application forever.
		@execTimeout = setTimeout () =>
			@killProcess()
			@launchDeferred.rejectWith @, [new Error("Timeout in testing after #{Config.timeout}ms.")]
		, Config.timeout

		# When the process exits, check if we we're called back
		@process.on 'exit', () =>
			if @didNotify
				@launchDeferred.resolveWith @
				@didNotify = false
			else
				clearTimeout @execTimeout
				@launchDeferred.rejectWith @, [new Error("""
					Process exited without calling back. Probably just another bad snapshot. 
					Could also be that you are not calling __buildcallbackWrapper() from your main html file.
					""")]

		@launchDeferred.promise()

	###
	# Tests the compiled snapshot.
	#
	# @returns {Promise}
	# @api private
	###
	test: () ->
		@testDeferred = dfd()
		@launch().fail (err) ->
			# Testing failed, clean up the snapshot so somebody doesn't 
			# accidentally use it some where.
			@cleanupSnapshot()
			@testDeferred.rejectWith @, [err]
		.done () ->
			# Testing succeeded.
			@testDeferred.resolveWith @
		@testDeferred.promise()

	###
	# Resets the snapshotter object's state.
	#
	# @returns {Boolean} always true
	# @api private
	###
	resetState: () ->
		@aborted = no
		@prepared = false
		@state = STATE_READY
		true

	###
	# Calls resetState and resolves the abortDeferred.
	#
	# @returns {Deferred}
	# @api private
	###
	resetStateAndResolve: () ->
		@resetState()
		@abortDeferred.resolveWith @

	###
	# Aborts current process, and properly cleans up.
	# This method is called from the server when an 'abort' event is recieved.
	#
	# @returns {Promise}
	# @api public
	###
	abort: () ->
		console.log 'abort!'
		@abortDeferred = dfd()
		@aborted = yes
		# The deferreds will fail once an async method is completed because of @aborted.
		switch @state
			when STATE_READY then @resetStateAndResolve()
			when STATE_CONFIGURING then @configurationDeferred.always @resetStateAndResolve
			when STATE_PREPARING then @preparationDeferred.always @resetStateAndResolve
			when STATE_BUILDING then @buildDeferred.always @resetStateAndResolve
			when STATE_MAKINGTEST then @makeDeferred.always @resetStateAndResolve
			when STATE_TESTING
				@launchDeferred.always @resetStateAndResolve
				# Kill the app to speed the process along.
				@killProcess()

		@abortDeferred.promise()
