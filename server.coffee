###############################################################################
##
##	TODO :	- Dynamicaly creates the response Header
##
###############################################################################

net = require 'net'
fs = require 'fs'
path = require 'path'

# The port to use
_PORT = 3333

# The web root folder
_WWW = './www'

# The Statut Codes Array
statutCodeArray =
	200: 'OK !!'
	404: 'Not Found !!'

# The Content-Types Array
contentTypeArray =
	html: 'text/html'
	'': 'text/html'
	map: 'text/plain'
	css: 'text/css'
	js: 'application/javascript'
	jpg: 'image/jpeg'
	jpeg: 'image/jpeg'
	mp3: 'audio/mp3'
	mp4: 'video/mpeg'


### OUMPA-LOUMPAS #############################################################

# Create 404 error page
createError404 = (err)->
	htmlError = "<!DOCTYPE HTML>
		<html>
			<head>
			<meta charset='UTF-8'>
				<link rel='stylesheet' href='//maxcdn.bootstrapcdn.com/font-awesome/4.3.0/css/font-awesome.min.css'/>
			</head>
			<body>
				<div align='center'><i class='fa fa-ban fa-5x'></i></div>
				<h1 align='center'>The page you're looking for doesn\'t exist !!</h1>
				<br>
				<br>
				<br>
				<div align='center'> #{err} </div>
				<br>
				<br>
				<br>
				<br>
			</body>
			<footer>
				<div align='center'> Mon Serveur Web à moi ... &#169;Moi</div>
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

	statutCode = 200

	# Get the MIME content-type from the file extension
	realPath = path.normalize(realPath) # to take care of // or /.. or /.
	extension = path.extname realPath
	extension = extension.substr 1
	contentType = contentTypeArray[extension]

	# Create a readable fileStream from the realPath
	fileStream = fs.createReadStream realPath

	# If their is a readable filestream, pipe it to the socket
	fileStream.on 'readable', ->
		respHeader = createRespHeader 200, contentType
		socket.write respHeader, ->
			fileStream.pipe socket

	# When their is no more data to read from the fileStream, close the socket
	fileStream.on 'end', ->
		socket.end()

	# FILESTREAM error, log it and close the socket
	fileStream.on 'error', (err)-> #URL doesnt exist
		console.error 'FILESTREAM : il y a une erreur:', err.toString 'utf8'
		respHeader = createRespHeader 404, contentType
		socket.write respHeader, ->
			socket.end createError404(err)

	# SOCKET error, log it and close the socket
	socket.on 'error', (err)->
		console.error 'SOCKET : il y a une erreur:', err.toString 'utf8'
		socket.end()


### WILLY WONKA ###############################################################

# Create the server instance
server = net.createServer (socket)->

	# When the 'data' event is fired from the socket
	socket.on 'data', (reqHeader)->

		# Get the filePath (the file to serve) from the request Header
		filePath = parseReqHeader reqHeader

		# Turn the filePath into a pseudo 'absolute' path
		realPath = path.join(_WWW, if filePath is '/' then 'index.html' else filePath)

		# Create the response (header & body) and send it
		processResponse realPath, socket


# Launch the server and listen to port 3333
server.listen _PORT, ->
	console.log "\r\nWebServer ONline on port: #{_PORT}\r\n"

