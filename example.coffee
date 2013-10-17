DeferredObject = require 'deferred-object'

obj = new DeferredObject {}
obj.defer 'person', (data, callback) ->
	process.nextTick () ->
		thing = new DeferredObject {}
		thing.defer 'name', (data, callback) ->
			process.nextTick () ->
				callback null, 'Richard'
		callback null, thing

obj.eval 'this.person.name', () ->
	console.log 'result', arguments
