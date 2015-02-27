net = require 'net'
fs = require 'fs'
path = require 'path'

header200 = '
			HTTP/1.0 200 OK\n
			Content-Type: text/html
			\r\n\r\n
			'

header404 = '
			HTTP/1.0 404 Not Found\n
			Content-Type: text/html
			\r\n\r\n
			'

headerJS = '
			HTTP/1.0 200 OK\n
			Content-Type: text/javascript
			\r\n\r\n
			'

headerCSS = '
			HTTP/1.0 200 OK\n
			Content-Type: text/css
			\r\n\r\n
			'

headerImg = '
			HTTP/1.0 200 OK\n
			Content-Type: application/octet-stream
			\r\n\r\n
			'

headerAudio = '
			HTTP/1.0 200 OK\n
			Content-Type: application/octet-stream
			\r\n\r\n
			'

headerVideo = '
			HTTP/1.0 200 OK\n
			Content-Type: application/octet-stream
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



www = './www/'



server = net.createServer (socket)->
	console.log 'Client Connected'
	socket.on 'end', ->
		console.log 'Client Disconnected'

	# socket.on 'data', (txt)->
	# 	fs.readFile www + index, (err, data)->
	# 		if err
	# 			socket.end header404 + htmlError
	# 			return

	# 		socket.end(header200 + data)

	socket.on 'data', cbSocketOn = (txt)->
		fs.readdir www, cbFsReadDir = (err, files)->
			if err
				socket.end header404 + htmlError
				return

			for file in files
				switch path.extname(file)
					when '.html' then fs.readFile path.join(www, file), cbFsReadFileHtml = (err, data)->
						if err
							throw err
						socket.resume()
						socket.write header200 + data, ->
							socket.pause()
					when '.css' then fs.readFile path.join(www, file), cbFsReadFileCss =  (err, data)->
						if err
							throw err
						socket.resume()
						socket.write headerCSS + data, ->
							socket.pause()
					when '.js' then fs.readFile path.join(www, file), cbFsReadFileJs =  (err, data)->
						if err
							throw err
						socket.resume()
						socket.write headerJS + data, ->
							socket.pause()
					when '.jpg' then fs.readFile path.join(www + 'images/', file), (err, data)->
						if err
							throw err
						socket.resume()
						socket.write headerImg + data, ->
							socket.pause()
					when '.mp3' then fs.readFile path.join(www + 'sounds/', file), (err, data)->
						if err
							throw err
						socket.resume()
						socket.write headerAudio + data, ->
							socket.pause()
					when '.mp4' then fs.readFile path.join(www + 'videos/', file), (err, data)->
						if err
							throw err
						socket.resume()
						socket.write headerVideo + data, ->
							socket.end()


server.listen 3333, ->
	console.log 'server ONline'
