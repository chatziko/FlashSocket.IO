package com.pnwrain.flashsocket {
	import com.adobe.net.URI
	import flash.external.ExternalInterface;
	import flash.utils.ByteArray;

	import socket.io.parser.Decoder;
	import socket.io.parser.Encoder;
	import socket.io.parser.Parser;
	import socket.io.parser.ParserEvent;

	import com.pnwrain.flashsocket.events.FlashSocketEvent;
	import com.pnwrain.flashsocket.events.EventEmitter;

	public class FlashSocket extends EventEmitter {

		public static var debug:Boolean = false;

		private var opts:Object;
		private var _uri:String;

		private var engine:Engine;

		private var ackId:int = 0;
		private var acks:Object = {};
		private var _receiveBuffer:Array = [];

		public var connected:Boolean;
		public var connecting:Boolean;

		private var encoder:Encoder;
		private var decoder:Decoder;


		public function FlashSocket(puri:String, popts:Object = null) {
			opts = popts || {};
			uri = puri;

			encoder = new Encoder();
			decoder = new Decoder();
			decoder.addEventListener(ParserEvent.DECODED, onDecoded);

			open();
		}

		public function get uri():String {
			return _uri;
		}

		public function	set uri(puri:String):void {
			_uri = puri;

			var parsed:URI = new URI(puri)

			opts.protocol = parsed.scheme;
			opts.host = parsed.authority + (parsed.port ? ':'+parsed.port : '');
			opts.query = parsed.query;
			opts.channel = parsed.path || "/";
		}

		public function get transport():String {
			return engine && engine.transport ? engine.transport.name : null;
		}

		private function open():void {
			connecting = true;

			engine = new Engine(opts);

			engine.on('data', onData);
			engine.on('close', onClose);
			engine.on('error', onError);
		};

		private function onData(ev:FlashSocketEvent):void {
			decoder.add(ev.data);
		}

		// called when a packet is fully decoded
		private function onDecoded(ev:ParserEvent):void {
			/* This is the higher-level socket.io protocol
			   https://github.com/automattic/socket.io-protocol
			   Packet#CONNECT (0)
			   Packet#DISCONNECT (1)
			   Packet#EVENT (2)
			   Packet#ACK (3)
			   Packet#ERROR (4)
			   Packet#BINARY_EVENT (5)
			   Packet#BINARY_ACK (6)
			 */
			var args:Array;
			var packet:Object = ev.packet;

			switch (packet.type) {
				case Parser.CONNECT:
					if (packet.nsp == opts.channel) {
						connected = true;
						connecting = false;

						_emit(FlashSocketEvent.CONNECT);

						emitBuffered()		// after CONNECT
					}
					else {
						sendPacket({
							type: Parser.CONNECT, nsp: opts.channel
						});
					}
					break;

				case Parser.EVENT:
				case Parser.BINARY_EVENT:
					args = packet.data || [];

					if(null != packet.id)
						// the message has packet.id so it wants an ack
						args.push(function(...args):void {
							sendAck(args, packet.id)
						})

					if(this.connected)
						_emit(args.shift(), args)
					else
						_receiveBuffer.push(args);

					break;

				case Parser.ACK:
				case Parser.BINARY_ACK:
					args = packet.data || [];
					if (this.acks.hasOwnProperty(packet.id)) {
						var func:Function = this.acks[packet.id] as Function;
						delete this.acks[packet.id];

						//pass however many args the function is looking for back to it
						if (args.length > func.length)
							func.apply(null, args.slice(0, func.length));
						else
							func.apply(null, args);
					}
					break;

				case Parser.DISCONNECT:
					onClose();
					break;

				case Parser.ERROR:
					log('3: error: ' + packet.data);

					_emit(FlashSocketEvent.ERROR, packet.data);
					break;
			}
		}

		private function onClose(e:FlashSocketEvent = null):void {
			log('engine closed', connecting, connected)

			var event:String =
				connected  ? FlashSocketEvent.DISCONNECT :
				connecting ? FlashSocketEvent.CONNECT_ERROR :
				null;

			destroy()

			if(event)
				_emit(event);
		};

		private function onError(e:FlashSocketEvent = null):void {
			// e.data is the actual event to emit (CONNECT_ERROR | IO_ERROR | ...)
			_emit(e.data);
			destroy();
		}

		// packet = { type: ..., data: ..., nsp: ... }
		//
		private function sendPacket(packet:Object):void {
			for each (var ioPacket:Object in encoder.encode(packet))
				engine.sendPacket('message', ioPacket, null, false);	// false = don't flush
			engine.flush();
		}

		public function emit(event:String, msg:Object, callback:Function = null):void {
			if(msg as Array)
				(msg as Array).unshift(event);
			else
				msg = [event, msg];

			var type:Number = hasBin(msg) ? Parser.BINARY_EVENT : Parser.EVENT;
			var packet:Object = { type: type, data: msg, nsp: opts.channel }

			if (null != callback) {
				var messageId:int = this.ackId;
				this.acks[this.ackId] = callback;
				this.ackId++;
				packet.id = messageId
			}

			sendPacket(packet);
		}

		private function sendAck(data:Array, id:String):void {
			sendPacket({
				type: hasBin(data) ? Parser.BINARY_ACK : Parser.ACK,
				data: data,
				nsp: opts.channel,
				id: id
			})
		}

		// returns try if val contains a ByteArray
		//
		private function hasBin(val:*):Boolean {
			if(val is ByteArray) {
				return true;
			} else if(typeof val == 'object') {
				for each (var elem:* in val)
					if(hasBin(elem))
						return true;
			}
			return false;
		}

		private function emitBuffered():void {
			if(!connected) return;	// just to be sure

			var i:int;
			for (i = 0; i < _receiveBuffer.length; i++) {
				var args:Array = _receiveBuffer[i] as Array
				_emit(args.shift(), args);
			}
			_receiveBuffer = [];
		}

		// full cleanup
		public function destroy():void {
			connected = connecting = false;

			if(engine) {
				// ignore further transport communication
				engine.removeListener('data', onData);
				engine.removeListener('close', onClose);
				engine.removeListener('error', onError);

				engine.close();
				engine = null;
			}

			if (decoder) {
				decoder.removeEventListener(ParserEvent.DECODED, onDecoded);
				decoder.destroy();
				decoder = null;
			}
			encoder = null;
			acks = null;
			opts = null;
			_receiveBuffer = null;
		}

		public function close():void {
			// if connected close engine, we'll destroy when closed
			if (connected || connecting)
				engine.close();
			else
				destroy()
		}


		///////////////////////////  logging  //////////////////////////////
		//
		//
		public static function log(...args):void {
			if(!debug) return;

			trace("FlashSocket: " + args.map(function(a:*, ...r):String { return JSON.stringify(a) }).join(' '));

			if(ExternalInterface.available) {
				args.unshift('console.log');
				ExternalInterface.call.apply(ExternalInterface, args);
			}
		}

		public static function error(message:String):void {
			trace("FlashSocket Error: " + message);
		}

		public static function fatal(message:String):void {
			trace("FlashSocket Error: " + message);
		}
	}
}
