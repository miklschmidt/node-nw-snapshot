###
# Dependencies
###

Config  = require './config'
Utils   = require './utils'
path    = require 'path'
fs      = require 'fs'
dfd     = require('jquery-deferred').Deferred
rimraf  = require 'rimraf'
mkdirp  = require 'mkdirp'
request = require 'request'

###
# NodeWebkitDownloader Class definition
###

module.exports = class NodeWebkitDownloader

	binFolder: "bin"

	###
	# Constructor for the class that configures which version, platform and 
	# architecture to use.
	# You can omit the platform and arch arguments and the instance will just 
	# default to the current platform and architecture.
	#
	# @param {Object} version
	# @param {String} [platform]
	# @param {String} [arch]
	# @return {NodeWebkitDownloader}
	# @api private
	###
	constructor: (@version, @platform = Config.platform, @arch = Config.arch) ->
		throw new Error "No version specified" unless @version
		unless @platform in ['win', 'osx', 'linux']
			throw new Error "Platform must be one of 'osx', 'linux' or 'win'"
		unless @arch in ['ia32', 'x64']
			throw new Error "Arch must be one of 'ia32' or 'x64'"
		if @platform in ['win', 'osx'] and @arch isnt 'ia32'
			throw new Error "Only ia32 is supported on osx and windows"
		if Config.platform is 'win' and @platform is 'linux'
			throw new Error "Extracting for linux on windows is unsupported at the moment. See: https://github.com/miklschmidt/node-nw-snapshot/issues/3"

	###
	# Returns the remote URL for the node-webkit archive.
	#
	# @return {String}
	# @api public
	###
	getDownloadURL: () ->
		extension = if @platform is 'linux' then 'tar.gz' else 'zip'
		"#{Config.downloadURL}/v#{@version}/node-webkit-v#{@version}-#{@platform}-#{@arch}.#{extension}"

	###
	# Returns the local path to the directory where the node-webkit 
	# distribution resides (or will be extracted to).
	#
	# @return {String}
	# @api public
	###
	getLocalPath: () ->
		path.join __dirname, '..', @binFolder, @version, "#{@platform}-#{@arch}"

	###
	# Returns the local path to the snapshot binary.
	# NOTE: The binary might not exist, see verifyBinaries().
	#
	# @return {String}
	# @api public
	###
	getSnapshotBin: () ->
		snapshotExecutable = if @platform is 'win' then 'nwsnapshot.exe' else 'nwsnapshot'
		folder = if @platform is 'linux' then "node-webkit-v#{@version}-#{@platform}-#{@arch}" else ""
		path.join @getLocalPath(), folder, snapshotExecutable

	###
	# Returns the local path to the node-webkit binary.
	# NOTE: The binary might not exist, see verifyBinaries().
	#
	# @return {String}
	# @api public
	###
	getNwBin: () ->
		switch @platform
			when 'win'
				path.join @getLocalPath(), 'nw.exe'
			when 'osx'
				path.join @getLocalPath(), 'node-webkit.app', 'Contents', 'MacOS', 'node-webkit'
			when 'linux'
				path.join @getLocalPath(), "node-webkit-v#{@version}-#{@platform}-#{@arch}", 'nw'

	###
	# Downloads the node-webkit archive.
	#
	# @return {Promise}
	# @api private
	###
	download: () ->
		downloadDeferred = dfd()
		url = @getDownloadURL()
		filename = url.split('/').slice(-1)[0]
		destinationFile = path.join @getLocalPath(), filename

		# Error handler
		handleError = (err) => downloadDeferred.rejectWith @, [err]

		# Create the directory
		if fs.existsSync(destinationFile)
			downloadDeferred.resolveWith @, [destinationFile]
		else
			mkdirp @getLocalPath(), (err) =>
				handleError err if err

				destinationStream = fs.createWriteStream destinationFile

				# Start the request for the file
				reqObj = {url}
				reqObj.proxy = process.env.http_proxy if process.env.http_proxy?
				req = request reqObj

				# Error handling
				
				destinationStream.on 'error', handleError
				req.on 'error', handleError

				# Success handling
				destinationStream.on 'close', () =>
					downloadDeferred.resolveWith @, [destinationFile]

				# We need to listen for the response event, since 404 responses don't seem to
				# trigger the error event. Without this check the promise would be resolved even 
				# if the server responded with 404.
				req.on 'response', (response) =>
					if response.statusCode isnt 200
						destinationStream.end()
						rimraf @getLocalPath(), (err) =>
							downloadDeferred.rejectWith @, [err] if err
							downloadDeferred.rejectWith @, [
								new Error("Bad response (code #{response.statusCode}. 
								           The version you requested (#{@version}) probably doesn't exist.")
							]
				# Pipe the request data to the local file
				req.pipe destinationStream

		downloadDeferred.promise()

	###
	# Deletes the directory where the node-webkit distribution resides.
	#
	# @return {Promise}
	# @api public
	###
	cleanVersionDirectoryForPlatform: () ->
		cleanDeferred = dfd()
		# Delete the directory and all its content.
		rimraf @getLocalPath(), (err) =>
			return cleanDeferred.rejectWith @, [err] if err
			cleanDeferred.resolveWith @

		cleanDeferred.promise()

	###
	# Extracts the node-webkit archive.
	#
	# @param {String} input
	# @param {String} output
	# @return {Promise}
	# @api private
	###
	extract: (input, output = @getLocalPath()) ->
		extractDeferred = dfd()
		# Check that the input file exists.
		unless fs.existsSync(input)
			return extractDeferred.rejectWith @, [
				new Error("The specified input file '#{input}' does not exist")
			]

		# Ensure that the extraction destination exists.
		mkdirp output, (err) =>
			return extractDeferred.rejectWith @, [err] if err

			# If extension is .tar or .tar.gz use Utils.untar
			if path.extname(path.basename(input, '.gz')) is '.tar'
				extractMethod = Utils.untar
			# if extension is .zip use Utils.unzip
			else if path.extname(input) is '.zip'
				extractMethod = Utils.unzip
			# unknown extension, throw error
			else extractDeferred.rejectWith @, [new Error("Unknown extension #{path.extname(input)}")]

			# extract!
			if extractMethod
				extractMethod(input, output)
				.done () =>
					extractDeferred.resolveWith @
				.fail (err) =>
					extractDeferred.rejectWith @, [err]
			else
				extractDeferred.rejectWith @, [new Error("No extract method")]

		# Always delete the archive after extraction or if the extraction fails
		extractDeferred.always () -> fs.unlinkSync input

		extractDeferred.promise()

	###
	# Verifies that the nw and nwsnapshot binaries exist.
	#
	# @return {Boolean}
	# @api public
	###	
	verifyBinaries: () ->
		fs.existsSync(@getSnapshotBin()) and fs.existsSync(@getNwBin())

	###
	# Ensures that the node-webkit distribution is available for use.
	#
	# @return {Promise}
	# @api public
	###
	ensure: () ->
		ensureDeferred = dfd()
		@versionExists = fs.existsSync(@getLocalPath())
		# Check if the version exists and verify that the binaries are present.
		if @versionExists and @verifyBinaries()
			ensureDeferred.resolveWith @, [@getSnapshotBin(), @getNwBin()]
		else
			# Always delete the old directory, there might be something left over
			# from a bad extraction or something. Basically be sure to start from scratch.
			@cleanVersionDirectoryForPlatform()
			# Download the distribution
			.then(@download)
			# Extract the downloaded archive
			.then(@extract)
			# Check if the binaries exist and resolve/reject
			.done () ->
				if @verifyBinaries()
					ensureDeferred.resolveWith @, [@getSnapshotBin(), @getNwBin()]
				else
					ensureDeferred.rejectWith @, [
						new Error("The expected binaries couldn't be 
							       found in the downloaded archive.")
					]
			# Something in the chain went wrong, reject the deferred.
			.fail (err) ->
				ensureDeferred.rejectWith @, [err]
		ensureDeferred.promise()