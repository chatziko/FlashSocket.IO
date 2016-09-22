# FlashSocket.IO

Flash client for [Socket.IO](http://socket.io/) version 1.0 and above. Connects
solely through WebSocket and supports binary data and native TLS (through
[SecureSocket](http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/net/SecureSocket.html)).

## Notes for this fork

This fork is based on
[redannick/FlashSocket.IO](https://github.com/redannick/FlashSocket.IO) (which
itself is based on
[jimib/FlashSocket.IO](https://github.com/jimib/FlashSocket.IO)) and contains
several improvements and bugfixes:

 * support for both polling and websockets
 * upgrade support (by default connect with polling and upgrade to websocket later)
 * support for sending/receiving binary data (as
   [ByteArray](http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/utils/ByteArray.html))
 * use [my fork](https://github.com/chatziko/AS3WebSocket) of
   [AS3WebSocket](https://github.com/theturtle32/AS3WebSocket), with the following improvements:
   * use native SecureSocket for TLS (faster, more sucure, reduces swc size by 86%)
   * limited support for [permessage-deflate](https://tools.ietf.org/html/draft-ietf-hybi-permessage-compression-19) compression
     (accept compressed messages from the server, although the client never compresses itself)
 * separate engine.io client code
 * add ERROR event for handling server-side errors
 * bugfix: propertly add callback to messages for sending ACK
 * bugfix: properly clean ACK callbacks
 * bugfix: emit buffered message after dispatching the CONNECT event
 * bugfix: stop heartbeat timer when socket abruptly closes
 * bugfix: dispatch DISCONNECT when connecting is manually close()ed
 * use native [JSON](http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/JSON.html)
 * remove CLOSE event (unclear semantics), use DISCONNECT instead
 * add destroy() method (similar to the js socket.io-client)

Tested with Socket.IO 1.4.

## Sample client and server

A sample [client](./sample/client.as) and [server](./sample/server.js) are provided.
To try them:

 * Install dependencies and start server
 ```
 cd sample
 npm install
 npm start
 ```

 * Compile the client, eg with ```mxmlc```:
 ```
 mxmlc --library-path=bin/Flash-Socket.IO.swc sample/client.as
 ```

 * Open [http://localhost:3000/](http://localhost:3000/)

