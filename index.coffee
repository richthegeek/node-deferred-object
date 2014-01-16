Contextify = require 'contextify'
Q = require 'q'
module.exports = class DeferredObject

	constructor: (data) ->
		@data = data

		keys = (k for k, v of @data when k isnt 'data')
		keys.forEach (k) =>
			@__defineGetter__ k, ->
				this.data[k]

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

			defer = Q.defer()
			getter key, @data, (err, result) =>
				error = defer.reject
				complete = defer.resolve

				if err
					return error err

				if Q.isPromise result
					result.then complete, error
				else
					complete result

			set defer.promise
			defer.promise.then (result) => set result
			throw defer.promise

	get: (key, context, callback) ->
		@eval "this.#{key}", context, callback

	eval: (str, context, callback) ->
		if typeof context is 'function'
			callback = context
			context = {}


		cb = (err, res) ->
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
