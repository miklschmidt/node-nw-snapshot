###
# Dependencies
###

Emitter      = require('events').EventEmitter
fs           = require 'fs'
PubSubSocket = require './pubsub.js'


###
# SnapshotClient class definition
###

module.exports = class SnapshotClient extends Emitter

	###
	# Constructs the class.
	#
	# @param {string} nwVersion
	# @param {(string|Buffer)} appSource
	# @param {(string|Buffer)} snapshotSource
	# @returns {SnapshotClient}
	# @api private
	###
	constructor: (nwVersion, appSource, snapshotSource) ->
		throw new Error("missing nwVersion parameter") unless nwVersion
		throw new Error("missing appSource parameter") unless appSource
		throw new Error("missing snapshotSource parameter") unless snapshotSource
		
		@nwVersion = nwVersion

		if typeof appSource is 'string' and fs.existsSync(appSource)
			@appSource = fs.readFileSync(appSource)
		else if appSource instanceof Buffer
			@appSource = appSource
		else
			throw new Error('appSource parameter should be a buffer or a valid (existing) filepath.')

		if typeof snapshotSource is 'string' and fs.existsSync(snapshotSource)
			@snapshotSource = fs.readFileSync(snapshotSource)
		else if snapshotSource instanceof Buffer
			@snapshotSource = snapshotSource
		else
			throw new Error('snapshotSource parameter should be a buffer or a valid (existing) filepath.')

		@connected = false

	###
	# Connects to the build server
	#
	# @param {(string|Number)} - If only a number is given address is assumed to be a port on localhost.
	# @param {Function} callback - called when connected
	# @returns {void}
	# @api public
	###
	connect: (address, callback) ->
		unless typeof address is 'string'
			address = 'tcp://127.0.0.1:' + address
		@socket = new PubSubSocket()
		@socket.connect(address)
		@socket.on 'connect', () =>
			@connected = true
			callback?()
		@socket.on 'message', () =>
			if arguments[0].toString() is 'done'
				@emit 'done', arguments[1], arguments[2].toString()
			else
				@emit arguments[0].toString(), arguments[1].toString(), arguments[2].toString()
		@socket.on 'close', () =>
			@connected = false

	###
	# Tells the buildserver to start compiling the snapshot, and disconnects when it's done.
	#
	# @param {Number} iterations - how many times to try compiling before giving up.
	# @returns {void}
	# @api public
	###
	build: (iterations) ->
		throw new Error("Not connected to build server") unless @connected
		@socket.send @nwVersion, @appSource, @snapshotSource, iterations + '' # axon breaks on numbers, 'cause they have no .length
		@socket.on 'message', (type) =>
			if type in ['done', 'fail']
				# Disconnect
				@disconnect()


	###
	# Disconnects from the buildserver.
	#
	# @returns {void}
	# @api public
	###
	disconnect: () ->
		@socket.removeAllListeners()
		@removeAllListeners()
		@socket.close()
		for sock in @socket.socks
			sock.end()
			sock.destroy()
			sock.unref() 
		@connected = false
