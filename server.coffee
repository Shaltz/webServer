net = require 'net'
fs = require 'fs'
path = require 'path'

www = './www'

htmlError = '<!DOCTYPE HTML>
	<html>
		<head>
		</head>
		<body>
			La page que vous recherchez n\'existe pas
		</body>
	</html>'

statutCode =
	200: 'OK !!'
	404: 'Not Found !!'


contentTypeArray =
	html: 'text/html'
	map: 'text/plain'
	css: 'text/css'
	js: 'application/javascript'
	jpg: 'image/jpeg'
	jpeg: 'image/jpeg'
	mp3: 'audio/mp3'
	mp4: 'video/mpeg'


#reqHeader
filePath = null


### mes OUMPA-LOUMPA ###
parseReqHeader = (reqHeader)->

	str = reqHeader.toString 'utf8'
	statusLine = str.substr 0, str.indexOf('\r\n')
	method = statusLine.substr 0, statusLine.indexOf(' ')
	protocol = statusLine.substr statusLine.indexOf('HTTP') #inutile
	filePath = statusLine.substring statusLine.indexOf(method) + method.length + 1, statusLine.indexOf ' HTTP'


processResponse = (realPath, socket)->

	# Getting the MIME content-type from the file extension
	extension = path.extname realPath
	extension = extension.substr 1
	contentType = contentTypeArray[extension]

	# Creating the response header
	respHeader = "HTTP/1.0 200 OK\r\nContent-Type: #{contentType}\r\n\r\n"

	# Creating a readable fileStream from the realPath
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
		fileStream.on 'error', (err)->
			console.error 'FILESTREAM : il y a une erreur :', err.toString 'utf8'
			socket.end()

	# SOCKET error, log it and close the socket
	socket.on 'error', (err)->
		console.error 'SOCKET : il y a une erreur:', err.toString 'utf8'
		socket.end()


### Willy Wonka ###
server = net.createServer (socket)->
	socket.on 'data', (reqHeader)->

		# Get the filePath (the file to serve) from the request Header
		filePath = parseReqHeader reqHeader

		# Turn the filePath into a pseudo 'absolute' path
		realPath = path.join(www, if filePath is '/' then 'index.html' else filePath)

		# Process the response from the realPath and the socket
		processResponse realPath, socket

server.listen 3333, ->
	console.log 'server ONline\r\n'

