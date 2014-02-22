var nwsnapshot = require('./index.js');
console.log('Starting socket on port ' + nwsnapshot.Config.sockPort)
console.log('Starting http server on port ' + nwsnapshot.Config.httpPort)
nwsnapshot.Server.start()