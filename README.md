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

 * support for sending/receiving binary data (as
   [ByteArray](http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/utils/ByteArray.html))
 * use [my fork](https://github.com/chatziko/AS3WebSocket) of
   [AS3WebSocket](https://github.com/theturtle32/AS3WebSocket), modified to use
   native SecureSocket for TLS (faster, more sucure, reduces swc size by 86%)
 * connect directly through WebSocket, without an initial polling request.  
   There was no polling implementation anyway, only a single initial request,
   it wasn't possible to receive messages before upgrading to WebSocket. Apart
   from the extra roundtrip, this had the undesired side-effect that the server
   thought we are already connected, while the client only considered itself
   connected after the upgrade.  
   A full polling implementation might be added in the future.
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

