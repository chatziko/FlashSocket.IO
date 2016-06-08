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

		public function WebSocket(popts:Object) {
			super(popts);

			name = 'websocket';
		}

		override public function open():void {
			super.open()

			// no sid cause we're not upgrading
			var protocol:String = opts.protocol;
			var host:String = opts.host;
			var query:String = opts.query;
			var sid:String = opts.sid;

			var socketURL:String = (protocol == 'https' ? 'wss' : 'ws') + "://" + host +
				"/socket.io/?EIO=3&transport=websocket" + (sid ? "&sid="+sid : "") + (query ? "&"+query : "");
			var origin:String = protocol + "://" + host.toLowerCase();

			webSocket = new com.worlize.websocket.WebSocket(socketURL, origin, [protocol]);

			webSocket.addEventListener(WebSocketEvent.OPEN, onWSOpen);
			webSocket.addEventListener(WebSocketEvent.MESSAGE, onMessage);
			webSocket.addEventListener(WebSocketEvent.CLOSED, onWSClose);
			webSocket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, onConnectionFail);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
			webSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);

			for each(var cert:ByteArray in opts.certificates)
				webSocket.addBinaryChainBuildingCertificate(cert, true);

			webSocket.connect();
		}

		override public function close():void {
			if(readyState != 'opening' && readyState != 'open')
				return;
			var connected:Boolean = webSocket.connected;	// might lose it after close()

			webSocket.close();

			// close event won't come unless we're connected
			if(!connected)
				onWSClose(null);
		}

		// sends a sequence of engine.io packets:
		// {
		//    type: close (1) | ping (2) | pong (3) | message (4) | upgrade (5)
		//    data: String (for text packets) | ByteArray (for binary packets)
		// }
		// see: https://github.com/socketio/engine.io-protocol
		//
		override public function send(packets:Array):void {
			writable = false;

			for(var i:Number = 0; i < packets.length; i++) {
				var type:int = typeCodes[packets[i].type];
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
				_emit('drain');
			}, 0);
		}

		private function onWSOpen(e:WebSocketEvent):void {
			super.onOpen();
		}

		private function onMessage(e:WebSocketEvent):void {
			var packet:Object = decodePacket(e.message.type == 'utf8' ? e.message.utf8Data : e.message.binaryData);
			FlashSocket.log('decoded packet', packet, packet.data is String);
			super.onPacket(packet);
		}

		private function onWSClose(e:WebSocketEvent):void {
			cleanup();
			super.onClose();
		}

		private function onConnectionFail(event:flash.events.Event):void {
			super.onError(FlashSocketEvent.CONNECT_ERROR);
		}

		private function onIoError(event:flash.events.Event):void {
			super.onError(FlashSocketEvent.IO_ERROR);
		}

		private function onSecurityError(event:flash.events.Event):void {
			super.onError(FlashSocketEvent.SECURITY_ERROR);
		}

		private function cleanup():void {
			if(webSocket) {
				// some flash player versions throw error if IO_ERROR arrives and is not handled, so add dummy handler
				webSocket.addEventListener(IOErrorEvent.IO_ERROR, function(e:*):void {});

				webSocket.removeEventListener(WebSocketEvent.OPEN, onWSOpen);
				webSocket.removeEventListener(WebSocketEvent.MESSAGE, onMessage);
				webSocket.removeEventListener(WebSocketEvent.CLOSED, onWSClose);
				webSocket.removeEventListener(WebSocketErrorEvent.CONNECTION_FAIL, onIoError);
				webSocket.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
				webSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
				webSocket = null;
			}
		}
	}
}
