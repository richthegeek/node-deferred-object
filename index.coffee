Q = require 'q'
module.exports = class DeferredObject

	constructor: (data) ->
		@data = data

		for k, v of @data
			do (k) =>
				@__defineGetter__ k, ->
					this.data[k]

	toJSON: ->
		result = {}
		for key, val of this.data
			if val.export?
				val = val.export()
			result[key] = val
		return result

	defer: (key, getter) ->
		Object.defineProperty @, key, get: =>
			if @data[key]
				return @data[key]

			defer = Q.defer()
			getter @data, (err, result) =>
				if err
					return defer.resolve [err]
				@data[key] = result
				defer.resolve [null, result]
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
