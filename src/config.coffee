parseArgs = require 'minimist'

config = {}
config.hostIP = '0.0.0.0'
config.arch = process.arch

args = parseArgs process.argv.slice(2)

if process.platform.match(/^darwin/) 
	config.platform = 'osx'
	portOffset = 0
else if process.platform.match(/^win/)
	config.platform = 'win'
	portOffset = 10
else 
	config.platform = 'linux'
	portOffset = 20

# Platform architecture
if args.arch
	config.arch = args.arch
	console.log "Using arch from CLI args: #{config.arch}"
else if process.env.npm_package_config_arch and process.env.npm_package_config_arch isnt 'false'
	config.arch = process.env.npm_package_config_arch
	console.log "Using arch from npm package configuration: #{config.arch}"
else
	config.arch = process.arch
	console.log "Defaulting to process.arch: #{config.arch}"

if config.arch not in ['ia32', 'x64']
	throw new Error("Unsupported platform architecture '#{config.arch}")
else
	# Socket port
	if args.sockport
		config.sockPort = args.sockport
		console.log "Using socket port from CLI args: #{config.sockPort}"
	else if process.env.npm_package_config_sockport and process.env.npm_package_config_sockport isnt 'false'
		config.sockPort = process.env.npm_package_config_sockport
		console.log "Using socket port from npm package configuration: #{config.sockPort}"
	else
		if config.arch is 'ia32'
			config.sockPort = 3001 + portOffset
		else if config.arch is 'x64'
			config.sockPort = 3002 + portOffset
		console.log "Defaulting socket port to #{config.sockPort}"
	# Http port
	if args.httpport
		config.httpPort = args.httpport
		console.log "Using socket port from CLI args: #{config.httpPort}"
	else if process.env.npm_package_config_httpport and process.env.npm_package_config_httpport isnt 'false'
		config.httpPort = process.env.npm_package_config_httpport
		console.log "Using socket port from npm package configuration: #{config.httpPort}"
	else
		if config.arch is 'ia32'
			config.httpPort = 3301 + portOffset
		else if config.arch is 'x64'
			config.httpPort = 3302 + portOffset
		console.log "Defaulting http port to #{config.httpPort}"


config.timeout = 10000 # ms before giving up and failing the test
config.callbackURL = "http://127.0.0.1:#{config.httpPort}/callback"

config.oldDownloadURL = "https://s3.amazonaws.com/node-webkit"
config.newDownloadURL = "http://dl.node-webkit.org"
config.nwjsDownloadUrl = "http://dl.nwjs.io"

module.exports = config