/**
 * NOTE: This is just a pure copy paste mix between 
 * axon.PubSocket and axon.SubSocket.
 */

/**
 * Module dependencies.
 */

var Socket = require('axon').Socket
  , debug = require('debug')('axon:pubsub')
  , escape = require('escape-regexp')
  , slice = require('axon/lib/utils').slice;

/**
 * Expose `PubSubSocket`.
 */

module.exports = PubSubSocket;

/**
 * Initialize a new `PubSubSocket`.
 *
 * @api private
 */

function PubSubSocket() {
  Socket.call(this);
  this.subscriptions = [];
}

/**
 * Inherits from `Socket.prototype`.
 */

PubSubSocket.prototype.__proto__ = Socket.prototype;

/**
 * Check if this socket has subscriptions.
 *
 * @return {Boolean}
 * @api public
 */

PubSubSocket.prototype.hasSubscriptions = function(){
  return !! this.subscriptions.length;
};

/**
 * Check if any subscriptions match `topic`.
 *
 * @param {String} topic
 * @return {Boolean}
 * @api public
 */

PubSubSocket.prototype.matches = function(topic){
  for (var i = 0; i < this.subscriptions.length; ++i) {
    if (this.subscriptions[i].test(topic)) {
      return true;
    }
  }
  return false;
};

/**
 * Message handler.
 *
 * @param {net.Socket} sock
 * @return {Function} closure(msg, mulitpart)
 * @api private
 */

PubSubSocket.prototype.onmessage = function(sock){
  var self = this;
  var patterns = this.subscriptions;

  if (this.hasSubscriptions()) {
    return function(msg, multipart){
      var topic = multipart
        ? msg[0].toString()
        : msg.toString();

      if (!self.matches(topic)) return debug('not subscribed to "%s"', topic);
      self.emit.apply(self, ['message'].concat(msg));
    }
  }

  return Socket.prototype.onmessage.call(this, sock);
};

/**
 * Subscribe with the given `re`.
 *
 * @param {RegExp|String} re
 * @return {RegExp}
 * @api public
 */

PubSubSocket.prototype.subscribe = function(re){
  debug('subscribe to "%s"', re);
  this.subscriptions.push(re = toRegExp(re));
  return re;
};

/**
 * Clear current subscriptions.
 *
 * @api public
 */

PubSubSocket.prototype.clearSubscriptions = function(){
  this.subscriptions = [];
};

/**
 * Send `msg` to all established peers.
 *
 * @param {Mixed} msg
 * @api public
 */

PubSubSocket.prototype.send = function(msg){
  var socks = this.socks
    , len = socks.length
    , sock;

  if (arguments.length > 1) msg = slice(arguments);
  msg = this.pack(msg);

  for (var i = 0; i < len; i++) {
    sock = socks[i];
    if (sock.writable) sock.write(msg);
  }

  return this;
};

/**
 * Convert `str` to a `RegExp`.
 *
 * @param {String} str
 * @return {RegExp}
 * @api private
 */

function toRegExp(str) {
  if (str instanceof RegExp) return str;
  str = escape(str);
  str = str.replace(/\\\*/g, '(.+)');
  return new RegExp('^' + str + '$');
}