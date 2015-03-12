
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
stream = require 'stream'


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
	500: 'Internal Server Error !!' # I'm broken... You broke me !!
	501: 'Not Implemented' # No can do !!!

funnyErrorCodeArray =
	400: "You're talking to me ??"
	403: "No Way !!"
	404: "No idea what you want !!"
	408: "Too Long, Can't Wait !!"
	500: "I'm broken... You broke me !!"
	501: "No can do !!!"

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
_STATUSLINE_RG = /^([A-Z]+) +((\/*[^\s]*)\/+([^\s]*)) +([A-Z]+)\/(.+)\r\n/ # check that the request status line looks like : GET /images/test.css HTTP/1.0


### OUMPA-LOUMPAS #############################################################

# Parse the request header... return an object with all the data from the request header
parseReqHeader = (reqHeader) ->

	strHeader = reqHeader.toString 'utf8'
	statusLineFields = _STATUSLINE_RG.exec strHeader

	if statusLineFields is null
		return null

	if _DEBUG
		console.log 'Request Header :', strHeader, '\n'

	statusLine = (statusLineFields[0].split('\\'))[0]

	requestInfos =
		statusLine: statusLine
		method: statusLineFields[1]
		fullPath: statusLineFields[2] # path + file
		path: statusLineFields[3] # just the path, no file
		file: statusLineFields[4] # file + extension
		protocol: statusLineFields[5]
		protocolVersion: statusLineFields[6]

# analyse and process the request header... returns an object with all the data needed to build a response header aswell as readable stream or an error page
processRequest = (reqHeader, socket, callback) ->

	requestFields = parseReqHeader reqHeader # Parse the request Header and returns an object with all the fields

	statusCode = 200
	root = _WEBROOT

	fullPath = requestFields.path
	fullPathArray = fullPath.split '/'

	if requestFields is null then statusCode = 400 # Bad request

	if requestFields.method is 'POST' then statusCode =  501 # not implemented

	if fullPathArray[1] is _SERVER_INTERNAL_CONFIG
		root = '.'

	if requestFields.fullPath is '/'
		target = path.join root, _INDEX
	else
		target = path.join root, requestFields.fullPath

	fs.stat target, (err, stats)->
		if err
			statusCode =  if statusCode is 200 then 404 else statusCode # not found
		else
			isDirectory = stats.isDirectory()
			if isDirectory
				tmpTarget = path.join target, _INDEX
				console.log '>>>>>>>>>>>>>>>>>>>>>>>>>> isDirectory :', tmpTarget

				try
					fs.accessSync tmpTarget
				catch err
					console.log '<<<<<<<<<< ACCESS error :', err
					statusCode =  403 # forbidden

				if statusCode isnt 403
					console.log '<<<<<<<<<< ACCESS OK'
					target = tmpTarget

	##################################################################################################


		if statusCode is 200 # if OK...
			fileToProcess = fs.createReadStream target
			lastModified = stats.mtime
			fileSize = stats.size
			contentType = getMIMEfromPath target

		else # if any error...
			fileToProcess = buildErrorPage statusCode
			lastModified = new Date
			contentType = 'text/html'

		infos =
			request:
				statusCode: statusCode
				method: requestFields.method
				protocol: requestFields.protocol
				protocolVersion: requestFields.protocolVersion
			file:
				name: requestFields.file
				fileToProcess: fileToProcess
				MIMEType: contentType
				mtime : lastModified
				size: fileSize

		callback infos

# Takes all the infos from the request header and creates the response header according... returns an object
buildResponseHeader = (infos, callback)->

	setTimeout ->
		#File Infos
		statusCode = infos.request.statusCode
		protocol = infos.request.protocol
		protocolVersion = infos.request.protocolVersion
		fileSize = infos.file.size
		filelastModified = infos.file.mtime
		contentType = infos.file.MIMEType

		# Get the Statut Message from the Statut Code
		statusMessage = statusCodeArray[statusCode]

		# Verify that the protocol version is handled by the server, if not, changes the protocol version to the server's
		if protocolVersion isnt _SERVER_PROTOCOL_VERSION
			if protocolVersion > _SERVER_PROTOCOL_VERSION
				protocolVersion  = _SERVER_PROTOCOL_VERSION

		if callback
			respHeader =
				statusLine:
					protocol: protocol
					protocolVersion: protocolVersion
					statusCode: statusCode
					statusMessage: statusMessage

				fields:
					Date: new Date
					'Content-Type': contentType
					'Content-Length': fileSize
					'Last-Modified': filelastModified
					Server: "#{_SERVER_NAME}/#{_SERVER_VERSION}"

				toString : ->
					crlf = '\r\n'
					header = "#{protocol}/#{protocolVersion} #{statusCode} #{statusMessage}#{crlf}"
					for key, value of @fields
						header += "#{key}: #{value}#{crlf}"
					header + crlf

			callback respHeader
	,0

# Looks at the fileToProcess and acts according... returns nothing
processResponse = (infos, socket)->

	fileToProcess = infos.file.fileToProcess
	statusCode = infos.request.statusCode

	if isReadableStream fileToProcess

		buildResponseHeader infos, (respHeader)->

			socket.write respHeader.toString(), ->
				if _DEBUG
					console.log "FILESTREAM.OPEN : #{infos.file.name} est ouvert !!\n"
				fileToProcess.pipe socket

			fileToProcess.on 'end', ->
				if _DEBUG
					console.log "FILESTREAM.END : #{infos.file.name} à été servit !!\n\n"
				socket.end()

			fileToProcess.on 'error', (err)->
				console.error "FILESTREAM.ERROR : il y a une erreur:", err['code'],
				"avec le fichier : #{infos.file.name}\n"

	else
		infos.file.size = Buffer.byteLength fileToProcess, 'utf8'

		buildResponseHeader infos, (respHeader)->
			socket.write respHeader.toString(), ->
				socket.end buildErrorPage statusCode

# Gets the MIME content-type from the file extension... returns the MIMEType of the file as a string
getMIMEfromPath = (filePath)->

	realPath = path.normalize(filePath) # to take care of // or /.. or /.
	extension = path.extname realPath
	extension = extension.substr 1
	contentType = contentTypeArray[extension]

	if contentType is undefined
		contentType = 'text/html'

	contentType

# Creates an Error Page... returns an error page as a string
buildErrorPage = (statusCode)->

	if !statusCode
		statusCode = 500

	errorMessage = htmlErrorMessage[statusCode]
	funnyMessage = funnyErrorCodeArray[statusCode]
	htmlErrorPage = "<!DOCTYPE HTML>
		<html>
			<head>
			<meta charset='UTF-8'>
			<title>Error : #{funnyMessage}</title>
			</head>
			<body>
				<div align='center'><img src='/libServer/ban.png'></i></div>
					<div style='height:450px'>
						<h1 align='center'>ERROR #{statusCode}</h1>
						<h2 align='center'>#{funnyMessage}</h2>
					</div>
			</body>
			<footer>
				<h2 align='center'>#{errorMessage}</h2>
				<p align='center'>#{_FOOTER}</p>
			</footer>
		</html>"

# Checks that an object is a readable qstream or not... returns true/false
isReadableStream = (obj)->

	obj instanceof stream.Stream && typeof obj.open is 'function'


### WILLY WONKA ###############################################################

# Create the server instance
server = net.createServer (socket)->

	# When the 'data' event is fired from the socket, responds to the request
	socket.on 'data', (reqHeader)->
		processRequest reqHeader, socket, (infos)->
			processResponse infos, socket

	# SOCKET TimeOut, throws an errorPage and closes the socket
	socket.on 'timeout', ->
		processResponse fileInfos, socket

	# SOCKET error, log it and close the socket (socket closed automaticaly when 'error' event is fired)
	socket.on 'error', (err)->
		if _DEBUG
			console.error 'SOCKET.ERROR : il y a une erreur:', err.toString 'utf8' + '\n'


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

