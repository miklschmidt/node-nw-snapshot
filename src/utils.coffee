###
# Dependencies
###

Config        = require './config'
fs            = require 'fs'
dfd           = require('jquery-deferred').Deferred
DecompressZip = require 'decompress-zip'
tar           = require 'tar'
exec          = require('child_process').exec
zlib          = require "zlib"

###
# Utils definition
###

module.exports =

	###
	# Unzip input into output.
	# Uses native unzip on osx and js implementation on linux and win
	#
	# @param {String} input
	# @param {String} output
	# @return {Promise}
	# @api private
	###
	unzip: (input, output) ->
		throw new Error "No input file specifed" unless input
		throw new Error "No ouput folder specified" unless output
		unzipDeferred = dfd()
		# Need to know which platform we're on which is 
		# why we don't use @platform.
		if Config.platform is 'osx'
			# Use native unzip
			exec "unzip -o '#{input}' -d '#{output}'", {cwd: output}, (err) =>
				return unzipDeferred.rejectWith @, [err] if err
				unzipDeferred.resolveWith @
		else
			# Unzip is not guaranteed on linux so use js unzip implementation.
			# Unfortunately most node.js zip implementations are
			# extremely flaky.
			unzip = new DecompressZip input
			unzip.on 'error', (err) =>
				unzipDeferred.rejectWith @, [err]
			unzip.on 'extract', () =>
				unzipDeferred.resolveWith @
			unzip.extract {path: output}
		
		unzipDeferred.promise()

	###
	# Untar input into output.
	# Uses native tar on osx and linux and js implementation on win
	#
	# @param {String} input
	# @param {String} output
	# @return {Promise}
	# @api private
	###
	untar: (input, output) ->
		untarDeferred = dfd()
		throw new Error "No input file specifed" unless input
		throw new Error "No ouput folder specified" unless output
		# Need to know which platform we're on which is 
		# why we don't use @platform.
		if Config.platform in ['osx', 'linux']
			# Use native tar
			exec "tar -xf '#{input}'", {cwd: output}, (err) =>
				return untarDeferred.rejectWith @, [err] if err
				untarDeferred.resolveWith @
		else
			# Baaaah windows.. Use js tar implementation
			# This is *incredibly* slow (150-300s).. But seems to work for now.
			src = fs.createReadStream input
			src.pipe(zlib.createGunzip()).pipe tar.Extract path: output
			.on 'end', () => untarDeferred.resolveWith @
			.on 'error', (err) => untarDeferred.rejectWith @, [err]

		untarDeferred.promise()