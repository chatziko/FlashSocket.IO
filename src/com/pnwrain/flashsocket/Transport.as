package com.pnwrain.flashsocket
{
	import flash.utils.ByteArray;

	import com.pnwrain.flashsocket.events.EventEmitter;
	import com.pnwrain.flashsocket.transports.WebSocket;
	import com.pnwrain.flashsocket.transports.Polling;

	public class Transport extends EventEmitter {

		static public function create(transport:String, socket:FlashSocket):Transport {
			return transport == 'polling'
				? new Polling(socket)
				: new WebSocket(socket);
		};

		static protected const typeCodes:Object = {
			open: 0,
			close: 1,
			ping: 2,
			pong: 3,
			message: 4,
			upgrade: 5,
			noop: 6
		};
		static protected const typeNames:Array = [
			'open', 'close', 'ping', 'pong', 'message', 'upgrade', 'noop'
		];


		public var name:String;
		protected var socket:FlashSocket;
		protected var readyState:String;
		public var writable:Boolean = false;


		public function Transport(psocket:FlashSocket) {
			socket = psocket;
		}

		public function open():void {
			readyState = 'opening';
		}

		public function close():void {
		}

		public function send(packets:Array):void {
		}

		protected function decodePacket(data:*):Object {

			var packet:Object = {};

			if(data is ByteArray) {
				packet.type = typeNames[data.readUnsignedByte()];

				// remove first byte without copy
				data.position = 0;
				data.writeBytes(data, 1, data.length - 1);
				data.length--;
				data.position = 0;	// ready to read

				packet.data = data;

			} else {
				// string
				data = decodeURIComponent(data);

				packet.type = typeNames[int(data.charAt(0))];
				packet.data = data.substr(1);
			}

			return packet;
		}

		// methods to be called by subclasses on various events
		protected function onOpen():void {
			readyState = 'open';
			writable = true;
			emit('open');
		}

		protected function onClose():void {
			writable = false
			readyState = 'closed';
			emit('close');
		}

		protected function onPacket(packet:Object):void {
			emit('packet', packet);
		}

		protected function onError(err:String):void {
			socket.log('transport error', err);
			emit('error', err);
		}
	}
}
