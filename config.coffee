config = {}
if process.platform.match(/^darwin/) 
	config.platform = 'osx'
	config.arch = 'ia32'
	config.sockPort = 3001
	config.httpPort = 3301
else if process.platform.match(/^win/) 
	config.platform = 'win'
	config.arch = 'ia32'
	config.sockPort = 3002
	config.httpPort = 3302
else 
	config.platform = 'linux'
	if process.arch is 'ia32'
		config.arch = 'ia32'
		config.sockPort = 3003
		config.httpPort = 3303
	else if process.arch is 'x64'
		config.arch = 'x64'
		config.sockPort = 3004
		config.httpPort = 3304
	else
		throw new Error("Unsupported platform architecture '#{process.arch}'")

config.timeout = 20000 # ms before giving up and failing the test
config.callbackURL = "http://localhost:#{config.httpPort}/callback"

config.downloadURL = "https://s3.amazonaws.com/node-webkit"

module.exports = config