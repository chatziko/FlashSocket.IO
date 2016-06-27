package com.pnwrain.flashsocket
{
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;

	import com.pnwrain.flashsocket.FlashSocket;
	import com.pnwrain.flashsocket.events.FlashSocketEvent;
	import com.pnwrain.flashsocket.events.EventEmitter;
	import com.pnwrain.flashsocket.transports.WebSocket;
	import com.pnwrain.flashsocket.transports.Polling;

	public class Transport extends EventEmitter {

		static public function create(transport:String, opts:Object):Transport {
			return transport == 'polling'
				? new Polling(opts)
				: new WebSocket(opts);
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
		protected var readyState:String;
		public var opts:Object;
		public var writable:Boolean = false;
		public var pausable:Boolean = false;
		private var connectTimeoutTimer:int = 0;


		public function Transport(popts:Object) {
			opts = popts;
		}

		public function open():void {
			readyState = 'opening';

			connectTimeoutTimer = setTimeout(onConnectTimeout, opts.connectTimeout || 20000);
		}

		public function close():void {
		}

		public function send(packets:Array):void {
		}

		public function pause(cb:Function):void {
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

		private function onConnectTimeout():void {
			onError(FlashSocketEvent.CONNECT_ERROR);
		}

		// should be overrided by subclasses
		protected function cleanup():void {
		}

		// methods to be called by subclasses on various events
		protected function onOpen():void {
			readyState = 'open';
			writable = true;

			clearTimeout(connectTimeoutTimer)

			_emit('open');
		}

		protected function onClose():void {
			writable = false
			readyState = 'closed';

			clearTimeout(connectTimeoutTimer)
			cleanup();

			_emit('close');
		}

		protected function onPacket(packet:Object):void {
			_emit('packet', packet);
		}

		protected function onError(err:String):void {
			FlashSocket.log('transport error', err);

			writable = false
			readyState = 'closed';

			clearTimeout(connectTimeoutTimer)
			cleanup();

			_emit('error', err);
		}
	}
}
