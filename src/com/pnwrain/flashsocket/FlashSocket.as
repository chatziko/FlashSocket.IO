package com.pnwrain.flashsocket
{
	import com.pnwrain.flashsocket.events.FlashSocketEvent;
	import com.worlize.websocket.WebSocket;
	import com.worlize.websocket.WebSocketEvent;
	import com.worlize.websocket.WebSocketErrorEvent;
	import com.adobe.net.URI
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	import flash.utils.ByteArray;
	import socket.io.parser.Decoder;
	import socket.io.parser.Encoder;
	import socket.io.parser.Parser;
	import socket.io.parser.ParserEvent;

	public class FlashSocket extends EventDispatcher
	{
		protected var debug:Boolean = false;
		protected var webSocket:WebSocket;

		//vars returned from discovery
		public var sessionID:String;

		//hold over variables from constructor for discover to use
		private var host:String;
		private var protocol:String;
		private var query:String;
		private var timer:Timer;
		private var channel:String;
		private var ackId:int = 0;
		private var acks:Object = {};
		private var heartBeatInterval:int;
		private var _receiveBuffer:Array = [];
		private var _keepaliveTimer:Timer;
		private var _pongTimer:Timer;
		private var heartBeatTimeout:int;
		public var connected:Boolean;
		public var connecting:Boolean;
		private var encoder:Encoder;
		private var decoder:Decoder;

		public function FlashSocket(uri:String, certificates:Array = null)
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

			connectSocket(certificates);
		}

		/*
		The socket.io protocol allows to start with polling and then uprgade to websocket. But the previous version of FlashSocket
		was _not_ properly doing this: it would do a polling request to connect, no other polling requests (losing incoming messages), then
		open websocket and only then it would consider the connection open and started receiving messages. So it needed websockets anyway, it
		would waste time on an initial polling request and risk to lose messages.

		So we removed the polling request completely, and only connect via websocket now (direct connect, not upgrade). The code below
		has been kept in case we implement proper polling in the future.

		protected function connectPolling():void {
			var r:URLRequest = new URLRequest();
			r.url = getConnectionUrl();
			r.method = URLRequestMethod.GET;

			var ul:URLLoader = new URLLoader(r);
			ul.addEventListener(Event.COMPLETE, onDiscover);
			ul.addEventListener(HTTPStatusEvent.HTTP_STATUS, onDiscoverError);
			ul.addEventListener(IOErrorEvent.IO_ERROR, onDiscoverError);
		}

		protected function getConnectionUrl():String
		{
			var connectionUrl:String = protocol + "://" + host + "/socket.io/?EIO=2&time=" + new Date().getTime()
			// socket.io 1.0 starts with a polling transport and then upgrades later. It requires this to be set in the url.
			connectionUrl += "&transport=polling" + (query ? "&"+query : "");
			return connectionUrl;
		}

		protected function onDiscover(event:Event):void
		{
			var response:String = event.target.data;
			var json:String = response.substr(response.indexOf("{"));
			setConnectionOptions(json);

			connectSocket();
		}

		protected function onDiscoverError(event:Event):void
		{
			if (event is HTTPStatusEvent)
			{
				if ((event as HTTPStatusEvent).status != 200)
				{
					//we were unsuccessful in connecting to server for discovery
					var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT_ERROR);
					dispatchEvent(fe);
				}
			}
		}
		*/

		protected function setConnectionOptions(json:String):void {
			var opts:Object = JSON.parse(json);
			sessionID = opts.sid;
			heartBeatTimeout = opts.pingTimeout;
			heartBeatInterval = opts.pingInterval;
		}

		protected function connectSocket(certificates:Array):void
		{
			// no sid cause we're not upgrading
			var socketURL:String = (protocol == 'https' ? 'wss' : 'ws') + "://" + host + "/socket.io/?EIO=3&transport=websocket" + (query ? "&"+query : "");
			var origin:String = protocol + "://" + host.toLowerCase();

			webSocket = new WebSocket(socketURL, origin, [protocol]);

			webSocket.addEventListener(WebSocketEvent.MESSAGE, onMessage);
			webSocket.addEventListener(WebSocketEvent.CLOSED, _onDisconnect);
			webSocket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, onConnectionFail);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
			webSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);

			for each(var cert:ByteArray in certificates)
				webSocket.addBinaryChainBuildingCertificate(cert, true);

			webSocket.connect();
		}

		protected function onConnectionFail(event:Event):void
		{
			var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT_ERROR);
			dispatchEvent(fe);
		}

		protected function onIoError(event:Event):void
		{
			var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.IO_ERROR);
			dispatchEvent(fe);
		}

		protected function onSecurityError(event:Event):void
		{
			var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.SECURITY_ERROR);
			dispatchEvent(fe);
		}

		public function log(message:String):void
		{
			if (debug)
			{
				trace("webSocketLog: " + message);
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

		/////////////////////////////////////////////////////////////////
		/////////////////////////////////////////////////////////////////
		protected var frame:String = '~m~';

		protected function onMessage(e:WebSocketEvent):void
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
			if(e.message.type == 'utf8') {
				// utf8 message
				var message:String = decodeURIComponent(e.message.utf8Data);

				if (message.charAt(0) == "0") {
					// the rest of the message is a json with connection options
					setConnectionOptions(message.substr(1));
				
				} else if (message == "3") {
					// response from server from the ping, so cancel the waiting
					_pongTimer.reset();

				// we don't do probing
				//} else if (message == "3probe") {
					// send the upgrade packet.
					//webSocket.sendUTF("5");

				} else if (message.charAt(0) == "4") {
					decoder.add(message.substr(1))
				}

			} else {
				// binary message
				var data:ByteArray = e.message.binaryData;
				var type:Number = data.readUnsignedByte()

				if(type == 4) {
					// remove first byte without copy
					data.position = 0;
					data.writeBytes(data, 1, data.length - 1);
					data.length--;
					data.position = 0;	// ready to read

					decoder.add(data);
				}
			}
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

			switch (packet.type)
			{
				case Parser.CONNECT:
					if (packet.nsp == this.channel)
					{
						this._onConnect(packet);
					}
					else
					{
						//if we're on a specific channel (namespace) then we need to tell the server to switch us over
						try
						{
							sendRawPackets(encoder.encode({type: Parser.CONNECT, nsp: this.channel}));
						}
						catch (err:Error)
						{

						}
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
					this._onDisconnect();
					break;

				case Parser.ERROR:
					log('3: error: ' + packet.data);

					var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.ERROR);
					fe.data = packet.data;
					dispatchEvent(fe);
					break;
			}
		}

		public function send(msg:Object, event:String = null, callback:Function = null):void
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

			try
			{
				sendRawPackets(encoder.encode(packet));
			}
			catch (err:Error)
			{
				fatal("Unable to send message: " + err.message);
			}
		}

		private function sendAck(data:Array, id:String):void
		{
			var type:Number = hasBin(data) ? Parser.BINARY_ACK : Parser.ACK;
			var packet:Object = { type: type, data: data, nsp: this.channel, id: id }

			try
			{
				sendRawPackets(encoder.encode(packet));
			}
			catch (err:Error)
			{
				fatal("Unable to send message: " + err.message);
			}
		}

		// this does the job of engine.io. Packets contains Strings (for text packets) and/or
		// ByteArrays (for binary packets). "4" is sent at the begining, denoting a message packet
		// see: https://github.com/socketio/engine.io-protocol
		//
		private function sendRawPackets(packets:Array):void {
			for(var i:Number = 0; i < packets.length; i++) {
				if(packets[i] is String) {
					webSocket.sendUTF("4" + packets[i]);
				} else {
					// new ByteArray (shouldn't modify the caller's data) with "4" at the beginning
					var data:ByteArray = new ByteArray();
					data.writeByte(4);
					data.writeBytes(packets[i], 0, packets[i].length);

					webSocket.sendBytes(data);
				}
			}
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

		public function emit(event:String, msg:Object, callback:Function = null):void
		{
			send(msg, event, callback)
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

		private function _onConnect(packet:Object):void
		{
			this.connected = true;
			this.connecting = false;

			_keepaliveTimer = new Timer(heartBeatInterval);
			_keepaliveTimer.addEventListener(TimerEvent.TIMER, keepaliveTimer_timer);
			_keepaliveTimer.start()

			_pongTimer = new Timer(heartBeatTimeout, 1);
			_pongTimer.addEventListener(TimerEvent.TIMER_COMPLETE, pongTimer_timerComplete);

			var e:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT);
			dispatchEvent(e);

			emitBuffered()		// after CONNECT
		}

		private function keepaliveTimer_timer(e:TimerEvent):void
		{
			if (_pongTimer.running)
				return;
			_pongTimer.start();

			// 2 - ping
			webSocket.sendUTF("2");
		}

		private function pongTimer_timerComplete(e:TimerEvent):void
		{
			fatal("Server Timed Out!!");
			close();
		}

		private function _onDisconnect(e:* = null):void
		{
			var dispatch:Boolean = connected
			destroy()

			if(dispatch) {
				var disc:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.DISCONNECT);
				dispatchEvent(disc);
			}
		}

		// full cleanup
		public function destroy():void {
			connected = connecting = false

			if (webSocket) {
				// some flash player versions throw error if IO_ERROR arrives and is not handled, so add dummy handler
				webSocket.addEventListener(IOErrorEvent.IO_ERROR, function(e:*):void {});

				webSocket.removeEventListener(WebSocketEvent.MESSAGE, onMessage);
				webSocket.removeEventListener(WebSocketEvent.CLOSED, _onDisconnect);
				webSocket.removeEventListener(WebSocketErrorEvent.CONNECTION_FAIL, onIoError);
				webSocket.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
				webSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
				webSocket.close();
				webSocket = null;
			}
			if (_keepaliveTimer) {
				_keepaliveTimer.removeEventListener(TimerEvent.TIMER, keepaliveTimer_timer);
				_keepaliveTimer.stop();
				_keepaliveTimer = null;
			}
			if (_pongTimer) {
				_pongTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, pongTimer_timerComplete);
				_pongTimer.stop();
				_pongTimer = null;
			}
			if (decoder) {
				decoder.destroy();
				decoder = null;
			}
			encoder = null;
			acks = null;
			_receiveBuffer = null;
		}

		public function close():void {
			// if connected close socket, we'll destroy when closed
			if (connected) {
				// stop timers now
				_keepaliveTimer.stop();
				_pongTimer.stop();

				webSocket.close();

			} else {
				destroy()
			}
		}
	}
}
