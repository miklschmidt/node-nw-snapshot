config = {}
if process.platform.match(/^darwin/) 
	config.platform = 'osx'
	config.port = 3001 
else if process.platform.match(/^win/) 
	config.platform = 'windows'
	config.port = 3002
else 
	config.platform = 'linux'
	if process.arch is 'ia32'
		config.port = 3003
	else if process.arch is 'x64'
		config.port = 3004 
	else
		throw new Error("Unsupported platform architecture '#{process.arch}'")

module.exports = config