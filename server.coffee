###############################################################################
##
##	TODO :	- Create an object to handle the header
##
###############################################################################

# config (webroot, port) from conf/conf.json
conf = require './conf/conf.json'

net = require 'net'
fs = require 'fs'
path = require 'path'


## CONSTANTS ##

# The port to use
_PORT = conf['_port']

# The web root folder
_WEBROOT = conf['_webroot']

# The HTML Footer Message
_FOOTER = conf['_HTML_Footer']

# Debug mode (true or false)
_DEBUG = conf['_debug']



# The Statut Codes Array
statutCodeArray =
	200: 'OK !!'
	404: 'Not Found !!'
	500: 'Internal Server Error !!'

# The HTML Messages on Errors
htmlErrorMessage =
	404: 'The page you\'re looking for doesn\'t exist !!'
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
				<link rel='stylesheet' href='//maxcdn.bootstrapcdn.com/font-awesome/4.3.0/css/font-awesome.min.css'/>
			</head>
			<body>
				<div align='center'><i class='fa fa-ban fa-5x'></i></div>
					<div style='height:600px'>
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
				<div align='center'>#{_FOOTER}</div>
			</footer>
		</html>"

# Create the response Header
createRespHeader = (statutCode, contentType)->

	# Get the Statut Message from the Statut Code
	statutMessage = statutCodeArray[statutCode]
	# Create the response header
	respHeader = "HTTP/1.0 #{statutCode} #{statutMessage}\r\nContent-Type: #{contentType}\r\n\r\n"


# Parse the request Header to extract data from it
parseReqHeader = (reqHeader)->

	# Turns the Request Header into a String
	str = reqHeader.toString 'utf8'
	# Extract the status line (the first line of the header)
	statusLine = str.substr 0, str.indexOf('\r\n')
	# Extract the method (POST/GET) from the status line
	method = statusLine.substr 0, statusLine.indexOf(' ')
	# Extract the protocol from the status line
	protocol = statusLine.substr statusLine.indexOf('HTTP') #inutile
	# Extract the file to serve (or filePath) from the status line
	filePath = statusLine.substring statusLine.indexOf(method) + method.length + 1, statusLine.indexOf ' HTTP'


# Process the Response from all the data available
processResponse = (realPath, socket)->

	# Get the MIME content-type from the file extension
	realPath = path.normalize(realPath) # to take care of // or /.. or /.
	extension = path.extname realPath
	extension = extension.substr 1
	contentType = contentTypeArray[extension]

	# Create a readable fileStream from the realPath
	fileStream = fs.createReadStream realPath

	# If there is a readable filestream, pipe it to the socket
	fileStream.on 'open', (data)->

		if _DEBUG
			console.log 'FILESTREAM.OPEN : Un fichier à été servit !'

		respHeader = createRespHeader 200, contentType
		socket.write respHeader, ->
			fileStream.pipe socket

	# When there is no more data to read from the fileStream, close the socket
	fileStream.on 'end', ->
		socket.end()

	# FILESTREAM error, log it and close the socket
	fileStream.on 'error', (err)-> #URL doesnt exist

		if _DEBUG
			console.error 'FILESTREAM.ERROR : il y a une erreur:', err['code']

		switch err['code']
			when 'ENOENT'
				_errorCode = 404
			else
				_errorCode = 500

		respHeader = createRespHeader _errorCode, 'text/html'
		socket.write respHeader, ->
			socket.end createErrorPage(err, _errorCode)


### WILLY WONKA ###############################################################

# Create the server instance
server = net.createServer (socket)->

	# When the 'data' event is fired from the socket
	socket.on 'data', (reqHeader)->

		# Get the filePath (the file to serve) from the request Header
		filePath = parseReqHeader reqHeader

		# Turn the filePath into a pseudo 'absolute' path
		_filePath = if filePath is '/' then 'index.html' else filePath;
		realPath = path.join(_WEBROOT, _filePath) ## simplifier cette partie (op. ternaire en dehors de l assignation) + generalisé la gestion d erreur

		# Create the response (header & body) and send it
		processResponse realPath, socket

	# SOCKET error, log it and close the socket (socket closed automaticaly when 'error' event is fired)
	socket.on 'error', (err)->

		if _DEBUG
			console.error 'SOCKET.ERROR : il y a une erreur:', err.toString 'utf8'


# Launch the server and listen to port 3333
server.listen _PORT, ->
	console.log "\r\nWebServer ONline on port: #{_PORT}\r\n"

	if _DEBUG
		console.log 'WebRoot :', _WEBROOT
		console.log 'Footer Message :', _FOOTER
		console.log 'Debug Mode:', _DEBUG

