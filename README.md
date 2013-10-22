# Deferred  Object
Add deferred properties to an object to allow lazy synchronous evaluation of asynchronous properties.

```
DeferredObject = require 'deferred-object'

obj = new DeferredObject {}
obj.defer 'person', (key, data, callback) ->
    process.nextTick () ->
		thing = new DeferredObject {}
		thing.defer 'name', (key, data, callback) ->
			process.nextTick () ->
				callback null, 'Richard'
		callback null, thing

obj.eval 'this.person.name', () ->
	console.log 'result', arguments
```
