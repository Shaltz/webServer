
EventEmitter = require('events').EventEmitter

emitter = new EventEmitter

emitter.on 'toto', (data)->
	console.log 'Toto event:', data


emitter.emit 'toto', 'titi'
