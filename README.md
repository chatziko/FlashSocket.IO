
# Redannicks changes: 
	updated to work with Socket.IO 1.0 (specifically 1.0.6)
	flashsocket transport is no longer required - uses polling that upgrages to websocket, same as js client.
	gimite/web-socket-js updated to most recent version
	querystring paramater support
	support for connecting to socket.io securely with ssl
	FlashSocket has a delegated EventDispatcher so you can replace with your own (for use with robotlegs)
	No Binary support


# NOTES

This isn't the original work of Jimib, this has been forked from git://github.com/simb/FlashSocket.IO.git which had an initial dependence on gimite/web-socket-js
The original project was only compatible with Flex and I needed a pure AS3 solution so I have tinkered the code and replaced a couple of Flex only classes. The most notable substitution has been of the mx.utils.URLUtil with com.jimisaacs.data.URL. The 2 classes are not directly interchangeable so I do expect some problems as a result.

# CREDIT

[https://github.com/simb/FlashSocket.IO](https://github.com/simb/FlashSocket.IO)

[https://github.com/gimite/web-socket-js](https://github.com/gimite/web-socket-js)

[http://jidd.jimisaacs.com/post/url-as3-class/](http://jidd.jimisaacs.com/post/url-as3-class/)

# FlashSocket.IO

Flash library to facilitate communication between Flex applications and Socket.IO servers.

The actual websocket communication is taken care of by my fork of gimite/web-socket-js project.

This project wraps that and facilitates the hearbeat and en/decoding of messages so they work with Socket.IO servers

# Checkout

