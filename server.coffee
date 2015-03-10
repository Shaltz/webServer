###############################################################################
##
##	TODO :	- Create an object to handle the header
##
###############################################################################

# config (webroot, port) from
_conf_path = './conf/conf.json'

conf = require _conf_path
net = require 'net'
fs = require 'fs'
path = require 'path'
querystring = require 'querystring'

## CONSTANTS ##

# The Server name and version number
_SERVER_NAME = 'WwWaiter'
_SERVER_PROTOCOL = 'HTTP/1.0'
_SERVER_VERSION = '0.1.0'

# The port to use
_PORT = conf['port']

# The web root folder
_WEBROOT = conf['webroot']

# The default index file
_INDEX = conf['defaultIndex']
# The HTML Footer Message
_FOOTER = conf['HTML_Footer_onError']

# Debug mode (true or false)
_DEBUG = conf['debug']



# The Statut Codes Array
statusCodeArray =
	200: 'OK !!'
	403: 'Forbidden !!'
	404: 'Not Found !!'
	414: 'Requested URI too long !!'
	500: 'Internal Server Error !!'

# The HTML Messages on Errors
htmlErrorMessage =
	403: 'The request couldn\'t be satisfied, forbidden element in the request URI !!'
	404: 'The page you\'re looking for doesn\'t exist !!'
	414: 'The requested URI is too long !!'
	500: 'The server has encountered an Internal Error !!'


# The Content-Types Array
contentTypeArray =
	html: 'text/html'
	txt: 'text/plain'
	map: 'text/plain'
	css: 'text/css'
	js: 'application/javascript'
	jpg: 'image/jpeg'
	jpeg: 'image/jpeg'
	gif: 'image/gif'
	mp3: 'audio/mpeg3'
	mp4: 'video/mpeg'


### OUMPA-LOUMPAS #############################################################

# Create an Error Page
createErrorPage = (err, errCode)->
	if !errCode
		errCode = 500

	displayErrorOnDebug = if _DEBUG then 'block' else 'none'

	errorMessage = htmlErrorMessage[errCode]
	htmlErrorPage = "<!DOCTYPE HTML>
		<html>
			<head>
			<meta charset='UTF-8'>
			<script>function getScreenHeight(){height = screen.height; window.alert(height);return height}</script>
			</head>
			<body>
				<div align='center'><img src='./libServer/ban.png'></i></div>
					<div style='height:450px'>
						<h1 align='center'>ERROR #{errCode}</h1>
						<h1 align='center'>#{errorMessage}</h1>
						<br>
						<br>
						<br>
						<div style=\"display:#{displayErrorOnDebug}\" align='center'> #{err} </div>
						<br>
						<br>
						<br>
						<br>
					</div>
			</body>
			<footer>
				<p align='center'>#{_FOOTER}</p>
			</footer>
		</html>"

# Get the MIME content-type from the file extension
getMIMEfromPath = (filePath)->

	# realPath = path.normalize(filePath) # to take care of // or /.. or /.
	extension = path.extname filePath
	extension = extension.substr 1
	contentType = contentTypeArray[extension]

# Build the response header from all the data available
buildRespHeader = (err, reqHeader, statusCode, filePath, callback)->

	fs.stat filePath, (err, stats)->
	#File Infos
		if err
			fileSize = Buffer.byteLength createErrorPage(err, statusCode), 'utf8'
		else
			fileSize = stats.size
			filelastModified = stats.mtime
			contentType = getMIMEfromPath filePath

	# Get the Statut Message from the Statut Code
		statusMessage = statusCodeArray[statusCode]

	# Request Header Parser
		protocol = (parseReqHeader reqHeader)['protocol']

		# Verify that the protocol version is handled by the server, if not, changes the protocol version to the server's
		if protocol isnt _SERVER_PROTOCOL
			if protocol is 'HTTP/0.9'
				protocol = 'HTTP/0.9'
			else
				protocol = _SERVER_PROTOCOL

			rn = '\r\n'

			# Object containing all the header informations
			respHeader =
				header : "#{protocol} #{statusCode} #{statusMessage}" + rn
				fields:
					date: new Date
					contentType: contentType ? 'text/html'
					contentLength: fileSize ? 0
					lastModified: filelastModified ? new Date
					server: "#{_SERVER_NAME}/#{_SERVER_VERSION}"

				# Append all the fields and their values to the status line to create the header
				toString : ->
					for key, value of respHeader.fields
						@header += key + ": " + value + rn
					@header + rn

		if callback
			callback respHeader


protectPath = (filePath, callback) ->
	setTimeout ->
		console.log 'filePath :', filePath
		regex = /(\.\.)/g
		response = regex.test filePath
		console.log 'protected filePath :', response
		callback response
		, 0



# Parse the request Header to extract data from it
parseReqHeader = (reqHeader)->

	# Turns the Request Header into a String
	str = reqHeader.toString 'utf8'
	# Extract the status line (the first line of the header)
	statusLine = str.substr 0, str.indexOf('\r\n')
	# Extract the method (POST/GET) from the status line
	method = statusLine.substr 0, statusLine.indexOf(' ')
	# Extract the file to serve (or filePath) from the status line
	filePath = statusLine.substring statusLine.indexOf(method) + method.length + 1, statusLine.indexOf ' HTTP'
	# Extract the protocol from the status line
	protocol = statusLine.substr statusLine.indexOf('HTTP')

	statusLine: statusLine
	method: method
	filePath: filePath
	protocol: protocol

# Process the Response from all the data available
processResponse = (reqHeader, requestedPath, socket)->

	# Create a readable fileStream from the requestedPath
	fileStream = fs.createReadStream requestedPath

	# If there is a readable filestream, pipe it to the socket
	fileStream.on 'open',(data)->

		if _DEBUG
			console.log 'FILESTREAM.OPEN : Un fichier à été servi !!'

		# Call buildRespHeader function to create the header and send the file
		buildRespHeader null, reqHeader, 200, requestedPath, (respHeader)->
			socket.write respHeader.toString(), ->
				fileStream.pipe socket

	# When there is no more data to read from the fileStream, close the socket
	fileStream.on 'end', ->
		socket.end()

	# FILESTREAM error, log it and close the socket
	fileStream.on 'error', (err)-> #URL doesnt exist

		if _DEBUG
			console.error 'FILESTREAM.ERROR : il y a une erreur:', err['code'], ' !!'

		switch err['code']
			when 'ENOENT'
				_statuCode = 404
			when 'ENAMETOOLONG'
				_statuCode = 414
			else
				_statuCode = 500

		# Call buildRespHeader function to create the header and the error  Page
		buildRespHeader err, reqHeader, _statuCode, requestedPath, (respHeader)->
			socket.write respHeader.toString(), ->
				socket.end createErrorPage err, _statuCode



### WILLY WONKA ###############################################################

# Create the server instance
server = net.createServer (socket)->

	# When the 'data' event is fired from the socket
	socket.on 'data', (reqHeader)->

		# Get the filePath (the file to serve) from the request Header
		filePath = (parseReqHeader reqHeader)['filePath']

		# Check if the filePazth contains "..", if it does, throw the forbidden error page
		protectPath filePath, (response)->

			if response is true
				# Call buildRespHeader function to create the header and the error  Page
				buildRespHeader null, reqHeader, 403, filePath, (respHeader)->
					socket.write respHeader.toString(), ->
						err = htmlErrorMessage['403']
						socket.end createErrorPage err, 403

			else

				# Turn the filePath into a pseudo 'absolute' path
				_filePath = if filePath is '/' then 'index.html' else filePath

				# Verify that the file is either in the webroot or in libServer
				_testServersFiles = /^\/libServer\//i
				_root = if _testServersFiles.test(filePath) then '.' else _WEBROOT

				requestedPath = path.join(_root, _filePath)

				# Create the response (header & body) and send it
				processResponse reqHeader, requestedPath, socket

	# SOCKET error, log it and close the socket (socket closed automaticaly when 'error' event is fired)
	socket.on 'error', (err)->

		if _DEBUG
			console.error 'SOCKET.ERROR : il y a une erreur:', err.toString 'utf8'


# Launch the server and listen to port 3333
server.listen _PORT, ->
	console.log '\r\n'
	console.log '####################################################'
	console.log '\r\n'
	console.log "    #{_SERVER_NAME} v#{_SERVER_VERSION} WebServer ONline on port: #{_PORT}"
	console.log '\r\n'
	console.log '####################################################'
	console.log '\r\n'

	if _DEBUG
		console.log 'Debug Mode:', _DEBUG
		console.log 'Configuration file:', _conf_path, '\r\n'
		console.log 'WebRoot :', _WEBROOT
		console.log 'Default Index file :', _INDEX
		console.log 'HTML Footer Message :', _FOOTER
		console.log '\r\n'

