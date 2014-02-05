path = require('path')
config = require('./config.coffee')
nwsnapshot = path.join(__dirname, 'bin', config.platform + '-' + process.arch, 'nwsnapshot.exe')