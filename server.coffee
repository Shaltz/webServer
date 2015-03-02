net = require 'net'
fs = require 'fs'
path = require 'path'

header200 = '
			HTTP/1.0 200 OK\r\n
			Content-Type: text/html
			\r\n\r\n
			'

header404 = '
			HTTP/1.0 404 Not Found\r\n
			Content-Type: text/html
			\r\n\r\n
			'

headerJS = '
			HTTP/1.0 200 OK\r\n
			Content-Type: text/javascript
			\r\n\r\n
			'

headerCSS = '
			HTTP/1.0 200 OK\r\n
			Content-Type: text/css
			\r\n\r\n
			'

headerImg = '
			HTTP/1.0 200 OK\r\n
			Content-Type: image/jpeg
			\r\n\r\n
			'

headerAudio = '
			HTTP/1.0 200 OK\r\n
			Content-Type: audio/mpeg3
			\r\n\r\n
			'

headerVideo = '
			HTTP/1.0 200 OK\r\n
			Content-Type: video/mpeg
			\r\n\r\n
			'


htmlTest = '<!DOCTYPE HTML>
	<html>
		<head>
		</head>
		<body>
			Ceci est un test HTML
		</body>
	</html>'

htmlError = '<!DOCTYPE HTML>
	<html>
		<head>
		</head>
		<body>
			La page que vous recherchez n\'existe pas
		</body>
	</html>'


www = './www'


server = net.createServer (socket)->

	socket.on 'data', cbSocketOnDATA = (header)->

		str = header.toString 'utf8'
		statusLine = str.substr 0, str.indexOf('\r\n')
		method = statusLine.substr 0, statusLine.indexOf(' ')
		protocol = statusLine.substr statusLine.indexOf('HTTP')
		filePath = statusLine.substring statusLine.indexOf(method) + method.length + 1, statusLine.indexOf ' HTTP'

		# console.log 'str : ' + str
		# console.log 'StatusLine : ' + statusLine
		# console.log 'method : ' + method
		console.log 'filePath : ' + filePath
		# console.log 'protocol : ' + protocol

		realPath =  path.join(www, 'index.html')

		if filePath is '/'

			fileStream = fs.createReadStream realPath
			socket.write header200, -> fileStream.pipe socket
			fileStream.on 'end', ->
				socket.end()
		else
			fileStream = fs.createReadStream path.join(www, filePath)

			switch path.extname(filePath)
				when '.css' then socket.write headerCSS, processFile(fileStream, socket)
				when '.js' then socket.write headerJS, processFile(fileStream, socket)
				when '.jpg' then socket.write headerImg, processFile(fileStream, socket)
				when '.mp3' then socket.write headerAudio, processFile(fileStream, socket)
				when '.mp4' then socket.write headerVideo, processFile(fileStream, socket)


processFile = (fileStream, socket)->
	fileStream.pipe socket
	fileStream.on 'end', cbFileStreamMP3 = ->
		socket.end()


server.listen 3333, ->
	console.log 'server ONline'

