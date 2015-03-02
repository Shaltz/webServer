net = require 'net'
fs = require 'fs'
path = require 'path'


headerHTML = '
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

headerJPG = '
			HTTP/1.0 200 OK\r\n
			Content-Type: image/jpeg
			\r\n\r\n
			'

headerAUDIO = '
			HTTP/1.0 200 OK\r\n
			Content-Type: audio/mpeg3
			\r\n\r\n
			'

headerVIDEO = '
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

		if filePath is '/'
			realPath = path.join(www, 'index.html')
			header = headerHTML
		else
			realPath = path.join(www, filePath)
			switch path.extname(filePath)
				when '.css' then header = headerCSS
				when '.js' then header = headerJS
				when '.jpg' then header = headerJPG
				when '.mp3' then header = headerAUDIO
				when '.mp4' then header = headerVIDEO
				else header = header404

		fileStream = fs.createReadStream realPath

		if header isnt header404
			socket.write header, processFile(fileStream, socket)
		else
			socket.end(header + htmlError)

server.listen 3333, ->
	console.log 'server ONline'

processFile = cbProcessFile = (fileStream, socket)->
	fileStream.pipe socket
	fileStream.on 'end', cbFileStream =->
		socket.end()



