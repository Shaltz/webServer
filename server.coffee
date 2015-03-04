net = require 'net'
fs = require 'fs'
path = require 'path'

#GLOBAL variables
filePath = null

################################################

# The web root
www = './www'

# The 404 error page
htmlError = "<!DOCTYPE HTML>
	<html>
		<head>
		<meta charset='UTF-8'>
			<link rel='stylesheet' href='//maxcdn.bootstrapcdn.com/font-awesome/4.3.0/css/font-awesome.min.css'/>
		</head>
		<body>
			<div align='center'><i class='fa fa-ban fa-5x'></i></div>
			<h1 align='center'>The page you're looking for doesn\'t exist !!</h1>
		</body>
		<footer>
			<div align='center'> Mon Serveur Web à moi ... &#169;Moi</div>
		</footer>
	</html>"

# The Statut Codes Array
statutCodeArray =
	200: 'OK !!'
	404: 'Not Found !!'

# The Content-Types Array
contentTypeArray =
	html: 'text/html'
	map: 'text/plain'
	css: 'text/css'
	js: 'application/javascript'
	jpg: 'image/jpeg'
	jpeg: 'image/jpeg'
	mp3: 'audio/mp3'
	mp4: 'video/mpeg'


### mes OUMPA-LOUMPA #############################################################

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
	extension = path.extname realPath
	extension = extension.substr 1
	contentType = contentTypeArray[extension]

	# Create the response header
	respHeader = "HTTP/1.0 200 OK\r\nContent-Type: #{contentType}\r\n\r\n"

	# Create a readable fileStream from the realPath
	fileStream = fs.createReadStream realPath

	# Write to the socket the response header
	socket.write respHeader, ->

		# If their is a readable filestream, pipe it to the socket
		fileStream.on 'readable', ->
			fileStream.pipe socket

		# When their is no more data to read from the fileStream, close the socket
		fileStream.on 'end', ->
			socket.end()

		# FILESTREAM error, log it and close the socket
		fileStream.on 'error', (err)-> #URL doesnt exist
			socket.end htmlError

	# SOCKET error, log it and close the socket
	socket.on 'error', (err)->
		console.error 'SOCKET : il y a une erreur:', err.toString 'utf8'
		socket.end()


### Willy Wonka ##################################################################

# Create the server instance
server = net.createServer (socket)->

	# When the 'data' event is fired from the socket
	socket.on 'data', (reqHeader)->

		# Get the filePath (the file to serve) from the request Header
		filePath = parseReqHeader reqHeader

		# Turn the filePath into a pseudo 'absolute' path
		realPath = path.join(www, if filePath is '/' then 'index.html' else filePath)

		# Create the response (header & body) and send it
		processResponse realPath, socket


# Launch the server and listen to port 3333
server.listen 3333, ->
	console.log 'server ONline\r\n'

