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
statusLine = null
method = null
protocol = null
filePath = null

#resHeader
extension = null
contentType = null


# mes OUMPA-LOUMPA
parseReqHeader = (reqHeader)->
	str = reqHeader.toString 'utf8'
	statusLine = str.substr 0, str.indexOf('\r\n')
	method = statusLine.substr 0, statusLine.indexOf(' ')
	protocol = statusLine.substr statusLine.indexOf('HTTP') #inutile
	filePath = statusLine.substring statusLine.indexOf(method) + method.length + 1, statusLine.indexOf ' HTTP'


processResponse = (realPath, socket)->

	extension = path.extname realPath
	extension = extension.substr 1
	contentType = contentTypeArray[extension]

	respHeader = "
				HTTP/1.0 200 OK\r\n
				Content-Type: #{contentType}
				\r\n\r\n
				"

	fileStream = fs.createReadStream realPath

	socket.write respHeader, ->
		fileStream.on 'readable', ->
			fileStream.pipe socket
		fileStream.on 'end', ->
			socket.end()

		# FILESTREAM error
		fileStream.on 'error', (err)->
			console.error 'FILESTREAM : il y a une erreur :', err.toString 'utf8'
			socket.end()

	# SOCKET error
	socket.on 'error', (err)->
		console.error 'SOCKET : il y a une erreur:', err.toString 'utf8'
		socket.end()


# Willy Wonka
server = net.createServer (socket)->
	socket.on 'data', (reqHeader)->

		filePath = parseReqHeader reqHeader
		realPath = path.join(www, if filePath is '/' then 'index.html' else filePath)

		processResponse realPath, socket

server.listen 3333, ->
	console.log 'server ONline\r\n'

