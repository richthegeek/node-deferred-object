Q = require 'q'
module.exports = class DeferredObject

	constructor: (data) ->
		@data = data

		for k, v of @data when k isnt 'data'
			do (k) =>
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
		@[key] ?= null
		@data[key] ?= null
		Object.defineProperty @, key, get: =>
			if val = @data[key]
				if Q.isPromise val
					throw val
				return val

			defer = Q.defer()
			getter key, @data, (err, result) =>
				error = (err) -> defer.reject err
				complete = (result) =>
					@data[key] = result
					defer.resolve result

				if err
					return error err

				if Q.isPromise result
					result.then complete, error
				else
					complete result

			@data[key] = defer.promise
			throw defer.promise

	get: (key, context, callback) ->
		@eval "this.#{key}", context, callback

	eval: (str, context, defer, callback) ->
		self = @

		# a bunch of shuffling to allow various arrangments of optional arguments
		args = Array::slice.call arguments, 1
		last = args.pop()

		if typeof last is 'function'
			callback = last
			last = args.pop()

		if last and last.promise?
			defer = last
			last = args.pop()
		else
			defer = Q.defer()

		context = last or {}

		onComplete = (result) ->
			if result? and result.then?
				return result.then onComplete, onReject
			callback? null, result
			defer.resolve result

		onResolve = (result) =>
			@eval str, context, defer, callback

		onReject = (reason) ->
			callback? reason
			defer.reject reason

		try
			`with(context) {
				(function() {
					onComplete(eval(str))
				}).call(self)
			}`
			return null
		catch err
			err.then ?= -> onReject err
			err.then onResolve, onReject

		return defer.promise
