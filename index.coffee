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
				if err
					return defer.resolve [err]
				@data[key] = result
				defer.resolve [null, result]

			@data[key] = defer.promise
			throw defer.promise

	get: (key, callback) ->
		@eval "this.#{key}", callback

	eval: (str, callback) ->
		try
			callback null, eval str
		catch err
			err.then ?= -> callback err
			err.then (arg) =>
				[err, result] = arg
				if err
					return callback err
				@eval str, callback
