
var fs = require('fs')
var http = require('http')
var https = require('https')
var express = require('express')
var policyfile = require('policyfile')
var ioServer = require('socket.io')


// CONFIGURATION. Set key/cert to enable https
var httpPort = 3000
var httpsPort = 3001
var key		// = "...path to key file..."
var cert	// = "...path to cert file..."

// basic express app to serve client.html and client.swf
var expressApp = express()
expressApp.use('/', express.static('.', { index: 'client.html' }))

// http server
var masterHttp = http.Server(expressApp)
masterHttp.listen(httpPort, function() {
	console.log('listening to port', httpPort)
	console.log('open http://localhost:'+httpPort+'/ in your browser')
})

// https server (if key/cert are set)
if(cert) {
	var credentials = {
		key: fs.readFileSync(key),
		cert: fs.readFileSync(cert),
	}
	var masterHttps = https.Server(credentials, expressApp)
	masterHttps.listen(httpsPort)
}

// serve policy file on httpPort, and also on port 843 if we can
var canOpenLowPorts = !process.getuid || process.getuid() == 0
var policyPort = canOpenLowPorts ? 843 : -1

policyfile.createServer().listen(policyPort, masterHttp)
if(cert)
	policyfile.createServer().listen(-1, masterHttps)

// socket.io server
var io = new ioServer(masterHttp)
if(cert)
	io.attach(masterHttps)

io.on('connection', function(socket) {
	console.log('client connected')

	console.log('sending foo')
	socket.emit('foo', 'bar', function(buf) {
		console.log('foo: got back', buf)
	})

	socket.on('bar', function(s, cb) {
		console.log("got 'bar' from client with data: " + s)
		console.log("sending back Buffer with 2 bytes")

		cb(new Buffer([1, 2]))
	})
})


