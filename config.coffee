config = {}
if process.platform.match(/^darwin/) 
	config.platform = 'osx'
	config.RPCPort = 3001
	config.answerPort = 3301
else if process.platform.match(/^win/) 
	config.platform = 'windows'
	config.RPCPort = 3001
	config.answerPort = 3301
else 
	config.platform = 'linux'
	if process.arch is 'ia32'
	config.RPCPort = 3003
	config.answerPort = 3303
	else if process.arch is 'x64'
	config.RPCPort = 3004
	config.answerPort = 3304
	else
		throw new Error("Unsupported platform architecture '#{process.arch}'")

config.timeout = 20000 # ms before giving up and failing the test

module.exports = config