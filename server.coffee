
###############################################################################
##
##	WwWaiter reboot
##
###############################################################################

# config (webroot, port) from
_conf_path = './conf/conf.json'

conf = require _conf_path
net = require 'net'
fs = require 'fs'
path = require 'path'


## CONSTANTS ##

# The Server name and version number
_SERVER_NAME = 'WwWaiter'
_SERVER_VERSION = '0.2.0'
_SERVER_PROTOCOL_VERSION = '1.0'
_SERVER_INTERNAL_CONFIG = 'libServer'

# The port to use
_PORT = conf['Port']

# The web root folder
_WEBROOT = conf['Webroot']

# The default index file
_INDEX = conf['DefaultIndex']

# The HTML Footer Message
_FOOTER = conf['HTML_Footer_onError']

# Debug mode (true or false)
_DEBUG = conf['Debug']


# The Statut Codes Array
statusCodeArray =
	200: 'OK !!' # yeah baby !!
	400: 'Bad Request !!' # you're talking to me ??
	403: 'Forbidden Access !!' # No Way !!
	404: 'Not Found !!' # No idea what you want !!
	408: 'Request timeOut !!' # Too Long, Can't Wait !!
	414: 'Request URI too long !!' # Wouah... calm down, mate !!
	500: 'Internal Server Error !!' # I'm broken... You broke me !!
	501: 'Not Implemented' # No can do !!!

# The HTML Messages on Errors
htmlErrorMessage =
	400: 'BAD REQUEST : The request received can\'t be understood !!'
	403: 'FORBIDDEN : You are NOT allowed to access this ressource !!'
	404: 'NOT FOUND : The page you\'re looking for doesn\'t exist !!'
	408: 'TIMEOUT : The request has takken too long to complete !!'
	414: 'TOO LONG : The Requested URI is too long !!'
	500: 'INTERNAL ERROR : The server has encountered an Internal Error !!'
	501: 'NOT IMPLEMENTED : This fonctionality isn\'t implemented'


# The Content-Types Array
contentTypeArray =
	html: 'text/html'
	txt: 'text/plain'
	map: 'text/plain'
	css: 'text/css'
	js: 'application/javascript'
	png: 'image/png'
	jpg: 'image/jpeg'
	jpeg: 'image/jpeg'
	gif: 'image/gif'
	mp3: 'audio/mpeg3'
	mp4: 'video/mpeg'

#REGEX
_STATUSLINE_RG = /^([A-Z]+) +((\/*[^\s]*)\/+([^\s]*)) +(HTTP\/(.+))$/m


### OUMPA-LOUMPAS #############################################################

processReqHeader = (reqHeader, socket, callback) ->

	setTimeout ->
		strHeader = reqHeader.toString 'utf8'

		if _DEBUG
			console.log 'Request Header :', strHeader, '\n\n'

		statusCode = 200
		root = _WEBROOT

		statusLineFields = _STATUSLINE_RG.exec strHeader

		console.log 'fields :', statusLineFields

		statusLine = statusLineFields[3]
		statusLineArray = statusLine.split '/'

		console.log 'statusLineArray :', statusLineArray

		if statusLineFields is null then statusCode = 400 # Bad request

		if statusLineFields[1] is 'POST' then statusCode =  501 # not implemented

		# if statusLineFields[4].length > 255 then statusCode =  414 # too long

		if statusLineArray[1] is _SERVER_INTERNAL_CONFIG
			root = '.'

		if statusLineFields[2] is '/'
			target = path.join root, _INDEX
		else
			target = path.join root, statusLineFields[2]

		fs.stat target, (err, stats)->

			if err
				statusCode =  if statusCode is 200 then 404 else statusCode # not found
			else
				isDirectory = stats.isDirectory()
				if isDirectory
					statusCode =  403 # forbidden

			lastModified = if statusCode is 200 then stats.mtime else new Date
			fileSize = if statusCode is 200 then stats.size else Buffer.byteLength buildErrorPage(statusCode), 'utf8'

			fileInfos =
				statusCode: statusCode
				# statusLine: statusLineFields[0]
				method: statusLineFields[1]
				# requestedPath: statusLineFields[2]
				# directoryPath: statusLineFields[3]
				file: statusLineFields[4]
				# filePath: directoryPath + file
				realPath: target
				protocol: (statusLineFields[5].split('/'))[0]
				protocolVersion: statusLineFields[6]
				mtime : lastModified
				size: fileSize

			callback fileInfos
	,0


buildResponseHeader = (fileInfos, callback)->

	setTimeout ->
	#File Infos
		statusCode = fileInfos.statusCode
		protocol = fileInfos.protocol
		protocolVersion = fileInfos.protocolVersion
		realPath = fileInfos.realPath
		fileSize = fileInfos.size
		filelastModified = fileInfos.mtime

		contentType = getMIMEfromPath realPath

	# Get the Statut Message from the Statut Code
		statusMessage = statusCodeArray[statusCode]

		# Verify that the protocol version is handled by the server, if not, changes the protocol version to the server's
		if protocolVersion isnt _SERVER_PROTOCOL_VERSION
			if protocolVersion > _SERVER_PROTOCOL_VERSION
				protocolVersion  = _SERVER_PROTOCOL_VERSION

		if callback
			respHeader = {
				statusLine:{
					protocol: protocolVersion
					statusCode: statusCode
					statusMessage: statusMessage
					}
				date: new Date
				contentType: contentType
				contentLength: fileSize
				lastModified: filelastModified
				server: "#{_SERVER_NAME}/#{_SERVER_VERSION}"

				toString : ->
					"HTTP/#{@statusLine.protocol} #{@statusLine.statusCode} #{@statusLine.statusMessage}\r\nDate: #{@date}\r\nContent-Type: #{@contentType}\r\nContent-Length: #{@contentLength}\r\nLast-Modified: #{@lastModified}\r\nServer: #{@server}\r\n\r\n"
				}
			callback respHeader
	,0

processResponse = (fileInfos, socket)->
	buildResponseHeader fileInfos, (respHeader)->
		statusCode = fileInfos.statusCode
		requestedPath = fileInfos.realPath

		if statusCode is 200

			fileStream = fs.createReadStream requestedPath

			fileStream.on 'open', (data)->

				if _DEBUG
					console.log 'FILESTREAM.OPEN : Un fichier à été servit !'

				socket.write respHeader.toString(), ->
					fileStream.pipe socket

			fileStream.on 'end', ->
				socket.end()

			fileStream.on 'error', (err)->

				console.error 'FILESTREAM.ERROR : il y a une erreur:', err['code']

		else
			socket.write respHeader.toString(), ->
				socket.end buildErrorPage statusCode

# Get the MIME content-type from the file extension
getMIMEfromPath = (filePath)->

	realPath = path.normalize(filePath) # to take care of // or /.. or /.
	extension = path.extname realPath
	extension = extension.substr 1
	contentType = contentTypeArray[extension]

	if contentType is undefined
		contentType = 'text/html'

	contentType


# Create an Error Page
buildErrorPage = (statusCode)->

	if !statusCode
		statusCode = 500

	errorMessage = htmlErrorMessage[statusCode]
	htmlErrorPage = "<!DOCTYPE HTML>
		<html>
			<head>
			<meta charset='UTF-8'>
			</head>
			<body>
				<div align='center'><img src='/libServer/ban.png'></i></div>
					<div style='height:450px'>
						<h1 align='center'>ERROR #{statusCode}</h1>
						<h1 align='center'>#{errorMessage}</h1>
					</div>
			</body>
			<footer>
				<p align='center'>#{_FOOTER}</p>
			</footer>
		</html>"

# DEPRECATED Create an Error Page
buildErrorPageAsync = (statusCode, callback)->

	setTimeout ->
		if !statusCode
			statusCode = 500

		errorMessage = htmlErrorMessage[statusCode]
		htmlErrorPage = "<!DOCTYPE HTML>
			<html>
				<head>
				<meta charset='UTF-8'>
				<script>function getScreenHeight(){height = screen.height; window.alert(height);return height}</script>
				</head>
				<body>
					<div align='center'><img src='./libServer/ban.png'></i></div>
						<div style='height:450px'>
							<h1 align='center'>ERROR #{statusCode}</h1>
							<h1 align='center'>#{errorMessage}</h1>
						</div>
				</body>
				<footer>
					<p align='center'>#{_FOOTER}</p>
				</footer>
			</html>"
		callback htmlErrorPage
	, 0


### WILLY WONKA ###############################################################

# Create the server instance
server = net.createServer (socket)->

	# When the 'data' event is fired from the socket, responds to the request
	socket.on 'data', (reqHeader)->
		console.log '>>>>>>>>> reqHeader :\n', reqHeader.toString('utf8'), '\n'
		processReqHeader reqHeader, socket, (fileInfos)->
			processResponse fileInfos, socket

	# SOCKET TimeOut, throws an errorPage and closes the socket
	socket.on 'timeout', ->
		processResponse fileInfos, socket

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
		console.log 'LibServer :', _SERVER_INTERNAL_CONFIG
		console.log 'Default Index file :', _INDEX
		console.log 'HTML Footer Message :', _FOOTER
		console.log '\r\n'

