package com.pnwrain.flashsocket.transports {

	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.HTTPStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.utils.ByteArray;
	import flash.net.URLRequest;
	import flash.net.URLLoader;

	import com.pnwrain.flashsocket.FlashSocket;
	import com.pnwrain.flashsocket.Yeast;
	import com.pnwrain.flashsocket.Transport;
	import com.pnwrain.flashsocket.events.FlashSocketEvent;

	public class Polling extends Transport {

		private var polling:Boolean = false;
		private var pollLoader:URLLoader;
		private var sendLoader:URLLoader;
		private var yeast:Yeast = new Yeast();


		public function Polling(popts:Object) {
			super(popts);

			name = 'polling';
			pausable = true;
		}

		override public function open():void {
			super.open();

			poll();
		}

		private function request(data:* = null):URLRequest {
			var protocol:String = opts.protocol;
			var host:String = opts.host;
			var query:String = opts.query;
			var sid:String = opts.sid;

			var req:URLRequest = new URLRequest();
			req.method = (data ? 'POST' : 'GET');
            req.contentType = 'application/octet-stream';
			req.data = data;
			req.url = protocol + "://" + host + "/socket.io/?EIO=3&transport=polling" +
				"&t=" + yeast.next() + (sid ? "&sid="+sid : query ? "&"+query : "");

			return req;
		}

		private function poll():void {
			polling = true;

			FlashSocket.log('polling');

			pollLoader = new URLLoader();
			pollLoader.dataFormat = 'binary';
			pollLoader.addEventListener(Event.COMPLETE, onPollData);
			pollLoader.addEventListener(HTTPStatusEvent.HTTP_STATUS, onPollHttpStatus);
			pollLoader.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
			pollLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
			pollLoader.load(request());
		}

		override public function close():void {
			FlashSocket.log("Polling.close", readyState)
			if(readyState == 'opening') {
				// opening phase, wait until we're open and then close
				//
				once('open', function(e:*):void {
					close()
				})

			} else if(readyState == 'open') {
				send([{ type: 'close' }]);

				readyState = 'closing';

				// close as soon as the message is sent
				once('drain', function(e:Event):void {
					FlashSocket.log('Polling: close message send, closing')
					cleanup();
					onClose();
				})
			}
		}

		// sends a sequence of engine.io packets:
		// {
		//    type: close (1) | ping (2) | pong (3) | message (4) | upgrade (5)
		//    data: String (for text packets) | ByteArray (for binary packets)
		// }
		// see: https://github.com/socketio/engine.io-protocol
		//
		override public function send(packets:Array):void {
			if(readyState != 'open' && readyState != 'opening') return
			writable = false;

			var data:ByteArray = encodePayload(packets);

			sendLoader = new URLLoader();
			sendLoader.dataFormat = 'binary';
			sendLoader.addEventListener(HTTPStatusEvent.HTTP_STATUS, onSendHttpStatus);
			sendLoader.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
			sendLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
			sendLoader.load(request(data));
		}

		// pauses polling, calls cb() after current polling/sending is finished
		override public function pause(cb:Function):void {
			readyState = 'pausing';

			function pause():void {
				FlashSocket.log('paused');
				readyState = 'paused';
				cb();
			}

			if(polling || !writable) {
				var total:int = 0;

				if(polling) {
					FlashSocket.log('we are currently polling - waiting to pause');
					total++;
					once('pollComplete', function(e:*):void {
						FlashSocket.log('pre-pause polling complete');
						--total || pause();
					});
				}

				if(!writable) {
					FlashSocket.log('we are currently writing - waiting to pause');
					total++;
					once('drain', function(e:*):void {
						FlashSocket.log('pre-pause writing complete');
						--total || pause();
					});
				}
			} else {
				pause();
			}
		}

		private function onPollData(e:Event):void {
			var packets:Array = decodePayload(e.target.data);

			for each(var packet:Object in packets) {
				FlashSocket.log('polling decoded packet ', packet, packet.data is String);

				// if its a close packet, we close the ongoing requests
				if('close' == packet.type) {
					cleanup();
					super.onClose();
					return;
				}

				// otherwise handle the message
				super.onPacket(packet);

				// we consider the transport as open after processing the 'open' packet,
				// so that we have the sid for future polls/sends
				if('open' == packet.type)
					super.onOpen();
			}

			// if an event did not trigger closing
			if ('closed' != readyState) {
				// if we got data we're not polling
				polling = false;
				_emit('pollComplete');

				if('open' == readyState)
					poll();
				else
					FlashSocket.log('stopping poll - transport state ', readyState);
			}
		}

		private function onPollHttpStatus(event:HTTPStatusEvent):void {
			if(event.status != 200)
				super.onError(FlashSocketEvent.CONNECT_ERROR);
		}

		private function onSendHttpStatus(event:HTTPStatusEvent):void {
			if(event.status == 200) {
				// suuccess
				writable = true;
				_emit('drain');
			} else
				super.onError(FlashSocketEvent.IO_ERROR);
		}

		private function onIoError(event:flash.events.Event):void {
			super.onError(FlashSocketEvent.IO_ERROR);
		}

		private function onSecurityError(event:flash.events.Event):void {
			super.onError(FlashSocketEvent.SECURITY_ERROR);
		}

		// implementation of engine.io-parser's encodePayloadAsBinary
		// Encodes an array of packets in a single ByteArray
		// for each packet we write:
		//   <0=string | 1=binary><length><packetdata>
		//
		// packetdata = <type><data>
		//   utf8 encoded, including type, (for strings) or binary
		// length = length of binary or utf8
		//   written as separate digits (base-10 represtation) followed by 255
		//   eg 10 is written as bytes 1 0 255
		//
		private function encodePayload(packets:Array):ByteArray {
			var ba:ByteArray = new ByteArray();

			function writeLength(length:String):void {
				for(var i:int = 0; i < length.length; i++)
					ba.writeByte(int(length.charAt(i)));
				ba.writeByte(255);
			}

			for each(var packet:Object in packets) {
				var data:* = packet.data;

				if(data is ByteArray) {
					ba.writeByte(1);
					writeLength(1 + data.length);		// +1 for the type
					ba.writeByte(typeCodes[packet.type]);
					ba.writeBytes(data);

				} else {
					var utf8:ByteArray = new ByteArray();
					utf8.writeUTFBytes(typeCodes[packet.type] + (data || ''));

					ba.writeByte(0);
					writeLength(utf8.length);			// type is included in utf8
					ba.writeBytes(utf8);
				}
			}
			return ba;
		}

		// the inverse of encodePayload
		private function decodePayload(ba:ByteArray):Array {
			var packets:Array = [];

			while(ba.bytesAvailable) {
				var binary:int  = ba.readUnsignedByte();

				var l:String = "";
				var b:int;
				while((b = ba.readUnsignedByte()) != 255)
					l += String(b);
				var len:int = int(l);

				var data:*;
				if(binary) {
					data = new ByteArray();
					ba.readBytes(data, 0, len);
				} else {
					data = ba.readUTFBytes(len);
				}

				packets.push(decodePacket(data));
			}
			return packets;
		}

		private function cleanup():void {
			if(pollLoader) {
				pollLoader.addEventListener(IOErrorEvent.IO_ERROR, function(e:*):void {}); // ignore future errors
				pollLoader.removeEventListener(Event.COMPLETE, onPollData);
				pollLoader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, onPollHttpStatus);
				pollLoader.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
				pollLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
				pollLoader = null;
			}
			if(sendLoader) {
				sendLoader.addEventListener(IOErrorEvent.IO_ERROR, function(e:*):void {}); // ignore future errors
				sendLoader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, onSendHttpStatus);
				sendLoader.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
				sendLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
				sendLoader = null;
			}
		}
	}
}
