// Generated by CoffeeScript 1.7.1
var DeferredObject, blue;

blue = require('bluebird');

module.exports = DeferredObject = (function() {
  function DeferredObject(data, _locking) {
    var k, keys, v;
    this._locking = _locking != null ? _locking : true;
    this.data = data;
    this._locked = true;
    this._lockstack = [];
    keys = (function() {
      var _ref, _results;
      _ref = this.data;
      _results = [];
      for (k in _ref) {
        v = _ref[k];
        if (k !== 'data') {
          _results.push(k);
        }
      }
      return _results;
    }).call(this);
    keys.forEach((function(_this) {
      return function(k) {
        return _this.__defineGetter__(k, function() {
          return this.data[k];
        });
      };
    })(this));
  }

  DeferredObject.prototype.lock = function() {
    this._lockstack.forEach(function(r) {
      return r.lock();
    });
    return this._locked = true;
  };

  DeferredObject.prototype.unlock = function() {
    this._lockstack.forEach(function(r) {
      return r.unlock();
    });
    return this._locked = false;
  };

  DeferredObject.prototype.toJSON = function() {
    var key, result, val, _ref;
    result = {};
    _ref = this.data;
    for (key in _ref) {
      val = _ref[key];
      if (val && (val.toJSON != null)) {
        val = val.toJSON();
      }
      result[key] = val;
    }
    return result;
  };

  DeferredObject.prototype.defer = function(key, getter) {
    var set;
    set = (function(_this) {
      return function(val) {
        delete _this[key];
        return _this[key] = _this.data[key] = val;
      };
    })(this);
    if (this[key] == null) {
      this[key] = null;
    }
    this.data[key] = void 0;
    return Object.defineProperty(this, key, {
      get: (function(_this) {
        return function() {
          var promise, val;
          if (typeof _this.data[key] !== 'undefined') {
            val = _this.data[key];
            if (val.then != null) {
              throw val;
            }
            return val;
          }
          if (_this._locking && _this._locked) {
            return null;
          }
          promise = new blue(function(resolve, reject) {
            return getter(key, _this.data, function(err, result) {
              var unlock;
              if (err) {
                return reject(err);
              }
              if ((result != null ? result.then : void 0) != null) {
                return result.then(resolve, reject);
              } else {
                unlock = function(obj) {
                  if ((obj != null ? obj.unlock : void 0) != null) {
                    _this._lockstack.push(obj);
                    return obj.unlock();
                  }
                };
                unlock(result);
                if (Array.isArray(result)) {
                  result.forEach(unlock);
                }
                return resolve(result);
              }
            });
          });
          set(promise);
          promise.then(function(result) {
            return set(result);
          });
          throw promise;
        };
      })(this)
    });
  };

  DeferredObject.prototype.get = function(key, context, callback) {
    return this["eval"]("this." + key, context, callback);
  };

  DeferredObject.prototype["eval"] = function(str, context, callback) {
    var cb, onComplete, onReject, onResolve, sandbox;
    this.unlock();
    if (typeof context === 'function') {
      callback = context;
      context = {};
    }
    cb = (function(_this) {
      return function(err, res) {
        _this.lock();
        return callback(err, res);
      };
    })(this);
    onComplete = function(result) {
      if ((result != null) && (result.then != null)) {
        return result.then(onResolve, onReject);
      }
      return cb(null, result);
    };
    onResolve = (function(_this) {
      return function(result) {
        return process.nextTick(function() {
          return _this["eval"](str, context, callback);
        });
      };
    })(this);
    onReject = cb;
    sandbox = this;
    sandbox.result = null;
    sandbox.error = null;
    sandbox.str = str;
    return this.evalEval(str, sandbox, context, function(error, result) {
      if (error !== null) {
        if (error.then == null) {
          error.then = function() {
            return onReject(error);
          };
        }
        return error.then(onResolve, onReject);
      } else {
        return onComplete(result);
      }
    });
  };

  DeferredObject.prototype.evalEval = function(str, sandbox, context, callback) {
    var teval;
    teval = sandbox["eval"];
    
		with (sandbox) {
			with (context) {
				eval = global.eval
				try {
					result = eval(str)
				} catch (e) {
					error = e
				}
			}
		};
    sandbox["eval"] = teval;
    return callback(sandbox.error, sandbox.result);
  };

  return DeferredObject;

})();
