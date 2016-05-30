package com.pnwrain.flashsocket.transports {

	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;

	import com.worlize.websocket.WebSocket;
	import com.worlize.websocket.WebSocketEvent;
	import com.worlize.websocket.WebSocketErrorEvent;

	import com.pnwrain.flashsocket.FlashSocket;
	import com.pnwrain.flashsocket.Transport;
	import com.pnwrain.flashsocket.events.FlashSocketEvent;

	public class WebSocket extends Transport {

		private var webSocket:com.worlize.websocket.WebSocket;

		public function WebSocket(psocket:FlashSocket) {
			super(psocket);

			name = 'websocket';
		}

		override public function open():void {
			super.open()

			// no sid cause we're not upgrading
			var protocol:String = socket.protocol;
			var host:String = socket.host;
			var query:String = socket.query;

			var socketURL:String = (protocol == 'https' ? 'wss' : 'ws') + "://" + host + "/socket.io/?EIO=3&transport=websocket" + (query ? "&"+query : "");
			var origin:String = protocol + "://" + host.toLowerCase();

			webSocket = new com.worlize.websocket.WebSocket(socketURL, origin, [protocol]);

			webSocket.addEventListener(WebSocketEvent.OPEN, onOpen);
			webSocket.addEventListener(WebSocketEvent.MESSAGE, onMessage);
			webSocket.addEventListener(WebSocketEvent.CLOSED, onClose);
			webSocket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, onConnectionFail);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
			webSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);

			for each(var cert:ByteArray in socket.certificates)
				webSocket.addBinaryChainBuildingCertificate(cert, true);

			webSocket.connect();
		}

		override public function close():void {
			if (webSocket) {
				// some flash player versions throw error if IO_ERROR arrives and is not handled, so add dummy handler
				webSocket.addEventListener(IOErrorEvent.IO_ERROR, function(e:*):void {});

				webSocket.removeEventListener(WebSocketEvent.OPEN, onOpen);
				webSocket.removeEventListener(WebSocketEvent.MESSAGE, onMessage);
				webSocket.removeEventListener(WebSocketEvent.CLOSED, onClose);
				webSocket.removeEventListener(WebSocketErrorEvent.CONNECTION_FAIL, onIoError);
				webSocket.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
				webSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
				webSocket.close();
				webSocket = null;
			}
			writable = false
			emit('close')
		}

		// send an engine.io packet:
		// {
		//    type: close (1) | ping (2) | pong (3) | message (4) | upgrade (5)
		//    data: String (for text packets) | ByteArray (for binary packets)
		// }
		// see: https://github.com/socketio/engine.io-protocol
		//
		override public function send(packets:Array):void {
			writable = false;

			for(var i:Number = 0; i < packets.length; i++) {
				var type:int = packetTypes[packets[i].type];
				var data:*  = packets[i].data || '';

				if(data is String) {
					webSocket.sendUTF(String(type) + data);
				} else {
					// new ByteArray (shouldn't modify the caller's data) with "4" at the beginning
					var ba:ByteArray = new ByteArray();
					ba.writeByte(type);
					ba.writeBytes(data, 0, data.length);

					webSocket.sendBytes(ba);
				}
			}

			// fake drain
			// defer to next tick to allow Socket to clear writeBuffer
			setTimeout(function():void {
				writable = true;
				emit('drain');
			}, 0);
		}

		private function onOpen(e:WebSocketEvent):void {
			writable = true
		}

		private function onMessage(e:WebSocketEvent):void {
			emit('packet', e.message);
		}

		private function onClose(e:WebSocketEvent):void {
			close();
		}

		private function onConnectionFail(event:flash.events.Event):void {
			emit('error', FlashSocketEvent.CONNECT_ERROR);
		}

		private function onIoError(event:flash.events.Event):void {
			emit('error', FlashSocketEvent.IO_ERROR);
		}

		private function onSecurityError(event:flash.events.Event):void {
			emit('error', FlashSocketEvent.SECURITY_ERROR);
		}
	}
}
