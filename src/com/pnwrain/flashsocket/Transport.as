package com.pnwrain.flashsocket
{
	import com.pnwrain.flashsocket.events.EventEmitter;
	import com.pnwrain.flashsocket.transports.WebSocket;

	public class Transport extends EventEmitter {

		static public function create(transport:String, socket:FlashSocket):Transport {
			return transport == 'polling'
				? null
				: new WebSocket(socket);
		};

		static protected const packetTypes:Object = {
			close: 1,
			ping: 2,
			pong: 3,
			message: 4,
			upgrade: 5
		};

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
	}
}
