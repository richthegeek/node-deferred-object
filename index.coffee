blue = require 'bluebird'

module.exports = class DeferredObject

	constructor: (data, @_locking = true) ->
		@data = data
		@_locked = true
		@_lockstack = []

		keys = (k for k, v of @data when k isnt 'data')
		keys.forEach (k) =>
			@__defineGetter__ k, ->
				this.data[k]

	lock: ->
		@_lockstack.forEach (r) -> r.lock()
		@_locked = true
	unlock: ->
		@_lockstack.forEach (r) -> r.unlock()
		@_locked = false

	toJSON: ->
		result = {}
		for key, val of this.data
			if val and val.toJSON?
				val = val.toJSON()
			result[key] = val
		return result

	defer: (key, getter) ->

		set = (val) =>
			delete @[key]
			@[key] = @data[key] = val

		@[key] ?= null
		@data[key] = undefined
		Object.defineProperty @, key, get: =>
			if typeof @data[key] isnt 'undefined'
				val = @data[key]
				if val.then?
					throw val
				return val

			if @_locking and @_locked
				console.trace('locked', key)
				return null

			promise = new blue (resolve, reject) =>
				getter key, @data, (err, result) =>
					if err
						return reject err
					
					if result?.then?
						result.then resolve, reject
					
					else
						unlock = (obj) =>
							if obj?.unlock?
								@_lockstack.push obj
								obj.unlock()

						unlock result
						if Array.isArray result
							result.forEach unlock

						resolve result
			set promise
			promise.then (result) => set result
			throw promise

	get: (key, context, callback) ->
		@eval "this.#{key}", context, callback

	eval: (str, context, callback) ->
		@unlock()
		if typeof context is 'function'
			callback = context
			context = {}


		cb = (err, res) =>
			@lock()
			callback err, res

		onComplete = (result) ->
			if result? and result.then?
				return result.then onResolve, onReject
			cb null, result

		onResolve = (result) =>
			process.nextTick => @eval str, context, callback

		onReject = cb

		sandbox = @

		sandbox.result = null
		sandbox.error = null
		sandbox.str = str
		@evalEval str, sandbox, context, (error, result) ->
			if error isnt null
				error.then ?= -> onReject error
				error.then onResolve, onReject
			else
				onComplete result

	evalEval: (str, sandbox, context, callback) ->
		teval = sandbox.eval
		`
		with (sandbox) {
			with (context) {
				eval = global.eval
				try {
					result = eval(str)
				} catch (e) {
					error = e
				}
			}
		}`
		sandbox.eval = teval

		callback sandbox.error, sandbox.result
