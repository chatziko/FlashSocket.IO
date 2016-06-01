package com.pnwrain.flashsocket
{
	import com.adobe.net.URI
	import flash.external.ExternalInterface;

	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;

	import socket.io.parser.Decoder;
	import socket.io.parser.Encoder;
	import socket.io.parser.Parser;
	import socket.io.parser.ParserEvent;

	import com.pnwrain.flashsocket.events.FlashSocketEvent;
	import com.pnwrain.flashsocket.events.Event;

	public class FlashSocket extends EventDispatcher
	{
		public var debug:Boolean = false;

		public var id:String;

		public var host:String;
		public var protocol:String;
		public var query:String;

		private var channel:String;
		private var ackId:int = 0;
		private var acks:Object = {};
		private var _receiveBuffer:Array = [];

		private var pingInterval:int;
		private var pingIntervalTimer:int;
		private var pingTimeout:int;
		private var pingTimeoutTimer:int;

		private var writeBuffer:Array = [];
		private var prevBufferLen:int = 0;

		public var connected:Boolean;
		public var connecting:Boolean;
		public var upgrading:Boolean = false;
		public var readyState:String;

		public var certificates:Array;
		private var encoder:Encoder;
		private var decoder:Decoder;

		public var transport:Transport;
		public var transports:Array;
		public var upgrades:Array;

		public function FlashSocket(uri:String, opts:Object = null)
		{
			var parsed:URI = new URI(uri)

			protocol = parsed.scheme;
			host = parsed.authority + (parsed.port ? ':'+parsed.port : '');
			query = parsed.query;
			channel = parsed.path || "/";
			connecting = true;

			encoder = new Encoder();
			decoder = new Decoder();
			decoder.addEventListener(ParserEvent.DECODED, onDecoded);

			opts = opts || {};
			certificates = opts.certificates;
			transports = opts.transports || ['polling', 'websocket'];

			open();
		}

		///////////////////////////  engine.io  //////////////////////////////
		//
		//
		private function open():void {
			if(!transports.length)
				throw new Error('no transports');

			readyState = 'opening';

			var transport:Transport = Transport.create(transports[0], this);
			transport.open();
			setTransport(transport);
		};

		private function setTransport(newtran:Transport):void {
			log('setting transport ' + newtran.name);

			if(transport) {
				log('clearing existing transport ' + transport.name);
				transport.removeListener('drain',  onTransportDrain);
				transport.removeListener('packet', onTransportPacket);
				transport.removeListener('error',  onTransportError);
				transport.removeListener('close',  onTransportClose);
			}

			// set up transport
			transport = newtran;

			// set up transport listeners
			transport.on('drain',  onTransportDrain);
			transport.on('packet', onTransportPacket);
			transport.on('error',  onTransportError);
			transport.on('close',  onTransportClose);
		};

		protected function onHandshake(opts:Object):void {
			log('handshake', opts);

			id = opts.sid;
			upgrades = opts.upgrades.filter(function(u:*):* { return ~transports.indexOf(u) });
			pingTimeout = opts.pingTimeout;
			pingInterval = opts.pingInterval;

			//???	this.transport.query.sid = data.sid;

			onOpen();
			setPing();
		}

		private function onOpen():void {
			readyState = 'open';
			flush();

			// we check for `readyState` in case an `open`
			// listener already closed the socket
//			if ('open' == this.readyState && this.upgrade && this.transport.pause) {
//				debug('starting upgrade probes');
//				for (var i = 0, l = this.upgrades.length; i < l; i++) {
//					this.probe(this.upgrades[i]);
//				}
//			}
		}

		private function onHeartbeat(timeout:int):void {
			clearTimeout(pingTimeoutTimer);
			pingTimeoutTimer = setTimeout(function ():void {
				if('closed' == readyState)
					return;
				log("onHeartbeat closing", timeout)
				close();
			}, timeout);
		};

		/**
		 * Pings server every `pingInterval` and expects response * within `pingTimeout` or closes connection.
		 */
		private function setPing():void {
			clearTimeout(pingIntervalTimer);
			pingIntervalTimer = setTimeout(function ():void {
				log('writing ping packet - expecting pong within ' + pingTimeout + ' ms');
				sendPacket('ping');
				onHeartbeat(pingTimeout);
			}, pingInterval);
		};

		// sends engine.io packet
		private function sendPacket(type:String, data:* = null, options:Object = null, doFlush:Boolean = true):void {
			if('closing' == readyState || 'closed' == readyState)
				return;

			options = options || {};
			options.compress = false !== options.compress;

			var packet:Object = {
				type: type,
				data: data,
				options: options
			};
			writeBuffer.push(packet);

			if(doFlush)
				flush();
		};

		private function flush():void {
			if(!('closed' != readyState && transport.writable && !upgrading && writeBuffer.length))
				return;

			log('flushing ' + writeBuffer.length + ' packets in socket');

			transport.send(writeBuffer);
			// keep track of current length of writeBuffer
			// splice writeBuffer and callbackBuffer on `drain`
			prevBufferLen = writeBuffer.length;
		}

		protected function onTransportPacket(e:Event):void
		{
			/* This is the lower-level engine.io protocol
			 * https://github.com/socketio/engine.io-protocol
			   open:       0    // non-ws
			   , close:    1    // non-ws
			   , ping:     2
			   , pong:     3
			   , message:  4
			   , upgrade:  5
			   , noop:     6
			 */
			if(readyState != 'opening' && readyState != 'open') {
				log('packet received with socket readyState ' + readyState);
				return;
			}

			// Socket is live - any packet counts
			if(readyState == 'open')
				onHeartbeat(pingInterval + pingTimeout);

			var packet:Object = e.data;
			if (packet.type == 'open') {
				// data is a json connection options
				onHandshake(JSON.parse(packet.data));

			} else if(packet.type == "pong") {
				log('pong')
				setPing();

			// we don't do probing
			//} else if (message == "3probe") {
				// send the upgrade packet.
				//webSocket.sendUTF("5");

			} else if (packet.type == 'message') {
				decoder.add(packet.data);
			}
		}

		private function onTransportDrain(e:Event):void {
			writeBuffer.splice(0, prevBufferLen);

			// setting prevBufferLen = 0 is very important
			// for example, when upgrading, upgrade packet is sent over,
			// and a nonzero prevBufferLen could cause problems on `drain`
			prevBufferLen = 0;

			if(writeBuffer.length)
				flush();
		};

		private function onTransportClose(e:Event = null):void {
			log('transport closed', connected)

			var dispatch:String =
				connected  ? FlashSocketEvent.DISCONNECT :
				connecting ? FlashSocketEvent.CONNECT_ERROR :
				null;

			destroy()

			if(dispatch)
				dispatchEvent(new FlashSocketEvent(dispatch));
		};

		private function onTransportError(e:Event):void {
			log('transport error', e.data)
			destroy()

			var fe:FlashSocketEvent = new FlashSocketEvent(e.data);
			dispatchEvent(fe);
		}


		///////////////////////////  socket.io  //////////////////////////////
		//
		//
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

			switch (packet.type)
			{
				case Parser.CONNECT:
					if (packet.nsp == this.channel)
					{
						connected = true;
						connecting = false;

						var e:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT);
						dispatchEvent(e);

						emitBuffered()		// after CONNECT
					}
					else
					{
						sendSioPacket({
							type: Parser.CONNECT, nsp: this.channel
						});
					}
					break;

				case Parser.EVENT:
				case Parser.BINARY_EVENT:
					args = packet.data || [];

					if (null != packet.id)
					{
						// the message has packet.id so it wants an ack
						args.push(function(...args):void {
							sendAck(args, packet.id)
						})
					}

					if (this.connected)
					{
						var fem:FlashSocketEvent = new FlashSocketEvent(args.shift());
						fem.data = args;
						dispatchEvent(fem)
					}
					else
					{
						_receiveBuffer.push(args);
					}
					break;

				case Parser.ACK:
				case Parser.BINARY_ACK:
					args = packet.data || [];
					if (this.acks.hasOwnProperty(packet.id))
					{
						var func:Function = this.acks[packet.id] as Function;
						delete this.acks[packet.id];

						//pass however many args the function is looking for back to it
						if (args.length > func.length)
						{
							func.apply(null, args.slice(0, func.length));
						}
						else
						{
							func.apply(null, args);
						}

					}
					break;

				case Parser.DISCONNECT:
					this.onTransportClose();
					break;

				case Parser.ERROR:
					log('3: error: ' + packet.data);

					var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.ERROR);
					fe.data = packet.data;
					dispatchEvent(fe);
					break;
			}
		}

		// sends a high-level (socket.io) packet
		// packet = { type: ..., data: ..., nsp: ... }
		//
		private function sendSioPacket(packet:Object):void {
			for each (var ioPacket:Object in encoder.encode(packet))
				sendPacket('message', ioPacket, null, false);
			flush();
		}

		public function emit(event:String, msg:Object, callback:Function = null):void
		{
			if (msg as Array)
			{
				(msg as Array).unshift(event);
			} else
			{
				msg = [event, msg];
			}

			var type:Number = hasBin(msg) ? Parser.BINARY_EVENT : Parser.EVENT;
			var packet:Object = { type: type, data: msg, nsp: this.channel }

			if (null != callback)
			{
				var messageId:int = this.ackId;
				this.acks[this.ackId] = callback;
				this.ackId++;
				packet.id = messageId
			}

			sendSioPacket(packet);
		}

		private function sendAck(data:Array, id:String):void
		{
			sendSioPacket({
				type: hasBin(data) ? Parser.BINARY_ACK : Parser.ACK,
				data: data,
				nsp: this.channel,
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

		private function emitBuffered():void
		{
			var i:int;
			for (i = 0; i < _receiveBuffer.length; i++)
			{
				var args:Array = _receiveBuffer[i] as Array
				var fem:FlashSocketEvent = new FlashSocketEvent(args.shift());
				fem.data = args;
				dispatchEvent(fem);
			}
			_receiveBuffer = [];
		}

		// full cleanup
		public function destroy():void {
			connected = connecting = false;
			readyState = 'closed';

			if(transport) {
				// ignore further transport communication
				transport.removeListener('drain',  onTransportDrain);
				transport.removeListener('packet', onTransportPacket);
				transport.removeListener('error',  onTransportError);
				transport.removeListener('close',  onTransportClose);

				transport.close();
				transport = null;
			}

			clearTimeout(pingIntervalTimer);
			clearTimeout(pingTimeoutTimer);

			if (decoder) {
				decoder.destroy();
				decoder = null;
			}
			encoder = null;
			acks = null;
			_receiveBuffer = null;
			writeBuffer = [];
			prevBufferLen = 0;
		}

		public function close():void {
			// if connected close socket, we'll destroy when closed
			if (connected || connecting) {
				// stop timers now
				clearTimeout(pingIntervalTimer);
				clearTimeout(pingTimeoutTimer);

				transport.close();

			} else {
				destroy()
			}
		}


		///////////////////////////  logging  //////////////////////////////
		//
		//
		public function log(...args):void
		{
			if (debug)
			{
				trace("webSocketLog: " + args.map(function(a:*, ...r):String { return JSON.stringify(a) }).join(' '));

				if(ExternalInterface.available) {
					args.unshift('console.log');
					ExternalInterface.call.apply(ExternalInterface, args);
				}
			}
		}

		public function error(message:String):void
		{
			trace("webSocketError: " + message);
		}

		public function fatal(message:String):void
		{
			trace("webSocketError: " + message);
		}
	}
}
