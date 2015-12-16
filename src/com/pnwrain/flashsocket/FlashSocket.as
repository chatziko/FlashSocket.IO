package com.pnwrain.flashsocket
{
	import com.adobe.serialization.json.JSON;
	import com.jimisaacs.data.URL;
	import com.pnwrain.flashsocket.events.FlashSocketEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.system.Security;
	import flash.utils.Timer;
	import socket.io.parser.Decoder;
	import socket.io.parser.Encoder;
	import socket.io.parser.Parser;

	public class FlashSocket implements IWebSocketWrapper, IWebSocketLogger, IEventDispatcher
	{
		static private var id:int = 0;
		
		protected var debug:Boolean = false;
		protected var callerUrl:String;
		protected var socketURL:String;
		protected var webSocket:WebSocket;
		
		//vars returned from discovery
		public var sessionID:String;
		protected var connectionClosingTimeout:int;
		protected var protocols:Array;
		
		private var _eventDispatcher:IEventDispatcher = new EventDispatcher();
		//hold over variables from constructor for discover to use
		private var domain:String;
		private var protocol:String;
		private var proxyHost:String;
		private var proxyPort:int;
		private var headers:String;
		private var query:String;
		private var timer:Timer;
		private var channel:String = "";
		
		private var ackRegexp:RegExp = new RegExp('(\\d+)\\+(.*)');
		private var ackId:int = 0;
		private var acks:Object = {};
		private var _queryUrlSuffix:String;
		private var heartBeatInterval:int;
		private var _receiveBuffer:Array = [];
		private var _keepaliveTimer:Timer;
		private var _pongTimer:Timer;
		private var heartBeatTimeout:int;
		public var connected:Boolean;
		public var connecting:Boolean;
		
		public function FlashSocket(domain:String, protocol:String = null, proxyHost:String = null, proxyPort:int = 0, headers:String = null, query:String = null)
		{
			var httpProtocal:String = "http";
			var webSocketProtocal:String = "ws";
			
			_queryUrlSuffix = (domain.split("?")[1] != undefined) ? "?" + domain.split("?")[1] :
				"";
			
			var URLUtil:URL = new URL(domain);
			if (URLUtil.protocol == "https")
			{
				httpProtocal = "https";
				webSocketProtocal = "wss";
			}
			protocol = httpProtocal;
			
			domain = URLUtil.host;
			
			this.socketURL = webSocketProtocal + "://" + domain + "/socket.io/?EIO=2&transport=websocket" + (query ? "&"+query : "");
			this.callerUrl = httpProtocal + "://" + domain;
			
			this.domain = domain;
			this.protocol = protocol;
			this.proxyHost = proxyHost;
			this.proxyPort = proxyPort;
			this.headers = headers;
			this.query = query;
			this.channel = URLUtil.pathname || "/";
			
			if (this.channel && this.channel.length > 0 && this.channel.indexOf("/") !=
				0)
			{
				this.channel = "/" + this.channel;
			}
			
			var r:URLRequest = new URLRequest();
			r.url = getConnectionUrl(httpProtocal, domain);
			r.method = URLRequestMethod.GET;
			
			var ul:URLLoader = new URLLoader(r);
			ul.addEventListener(Event.COMPLETE, onDiscover);
			ul.addEventListener(HTTPStatusEvent.HTTP_STATUS, onDiscoverError);
			ul.addEventListener(IOErrorEvent.IO_ERROR, onDiscoverError);
		}
		
		protected function getConnectionUrl(httpProtocal:String, domain:String):String
		{
			var connectionUrl:String = httpProtocal + "://" + domain + "/socket.io/?EIO=2&time=" +
				new Date().getTime() + _queryUrlSuffix.split("?").join("&");
			// socket.io 1.0 starts with a polling transport and then upgrades later. It requires this to be set in the url.
			connectionUrl += "&transport=polling" + (query ? "&"+query : "");
			return connectionUrl;
		}
		
		protected function onDiscover(event:Event):void
		{
			var response:String = event.target.data;
			response = response.substr(response.indexOf("{"));
			var responseObj:Object = com.adobe.serialization.json.JSON.decode(response);
			
			sessionID = responseObj.sid;
			heartBeatTimeout = responseObj.pingTimeout;
			heartBeatInterval = responseObj.pingInterval;
			protocols = responseObj.upgrades;
			
			var flashSupported:Boolean = false;
			for (var i:int = 0; i < protocols.length; i++)
			{
				if (protocols[i] == "flashsocket")
				{
					flashSupported = true;
					break;
				}
			}
			
			socketURL += _queryUrlSuffix.split("?").join("&")
			var index:int = this.socketURL.lastIndexOf("/")
			this.socketURL = this.socketURL.slice(0, index) + this.socketURL.slice(index) +
				"&sid=" + sessionID;
			
			onHandshake(event);
		
		}
		
		protected function onHandshake(event:Event = null):void
		{
			webSocket = new WebSocket(FlashSocket.id++, socketURL, [protocol], getOrigin(), proxyHost, proxyPort, "", headers, this);
			
			webSocket.addEventListener(WebSocketEvent.MESSAGE, onMessage);
			webSocket.addEventListener(WebSocketEvent.CLOSE, onClose);
			webSocket.addEventListener(WebSocketEvent.OPEN, onOpen);
			webSocket.addEventListener(Event.CLOSE, onClose);
			webSocket.addEventListener(Event.CONNECT, onConnect);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, onIoError);
			webSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
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
		
		protected function onHandshakeError(event:Event):void
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
		
		protected function onClose(event:Event):void
		{
			var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CLOSE);
			dispatchEvent(fe);
		}
		
		protected function onConnect(event:Event):void
		{
			var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT);
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
		
		public function getOrigin():String
		{
			var URLUtil:URL = new URL(this.callerUrl);
			return (URLUtil.protocol + "://" + URLUtil.host.toLowerCase());
		}
		
		public function getCallerHost():String {
			return null;
			//I dont think we need this
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
		
		protected function onOpen(e:WebSocketEvent):void
		{
			//this is good I think
			
			//ask to upgrade the connection to websocket
			webSocket.send("2probe");
		}
		
		protected function onMessage(e:WebSocketEvent):void
		{
			var msg:String = decodeURIComponent(e.message);
			if (msg)
			{
				this._onMessage(msg);
			}
		}
		
		protected function onData(e:WebSocketEvent):void
		{
			
			var data:Object = e.message;
			
			if (data.type == "message")
			{
				var msg:String = decodeURIComponent(data.data);
				if (msg)
				{
					this._onMessage(msg);
				}
			}
			else if (data.type == "open")
			{
				//this is good I think
			}
			else if (data.type == "close")
			{
				var fe:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CLOSE);
				dispatchEvent(fe);
			}
			else
			{
				
				log("We got a data message that is not 'message': " + data.type);
			}
		}
		
		private function _onMessage(message:String):void
		{
			var args:Array;
			/*
			 * https://github.com/Automattic/socket.io-client/blob/master/socket.io.js#L3460
			   open:     0    // non-ws
			   , close:    1    // non-ws
			   , ping:     2
			   , pong:     3
			   , message:  4
			   , upgrade:  5
			   , noop:     6
			 */
			if (message == "3")
			{
				// response from server from the ping, so cancel the waiting
				_pongTimer.stop();
				return;
			}
			if (message == "3probe")
			{
				// send the upgrade packet.
				webSocket.send("5");
				return;
			}
			
			if (message.charAt(0) == "4")
			{
				var packet:Object = new Decoder().decode(message);
				//https://github.com/automattic/socket.io-protocol
				/*	Packet#CONNECT (0)
				   Packet#DISCONNECT (1)
				   Packet#EVENT (2)
				   Packet#ACK (3)
				   Packet#ERROR (4)
				   Packet#BINARY_EVENT (5)
				   Packet#BINARY_ACK (6)
				 */
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
								webSocket.send(new Encoder().encodeAsString({type: 0, nsp: this.channel}));
							}
							catch (err:Error)
							{
								
							}
						}
						break;
					
					case Parser.EVENT:
						
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
			
			var packet:Object = {type: Parser.EVENT, data: msg, nsp: this.channel}
			
			if (null != callback)
			{
				var messageId:int = this.ackId;
				this.acks[this.ackId] = callback;
				this.ackId++;
				packet.id = messageId
			}
			
			try
			{
				webSocket.send(new Encoder().encodeAsString(packet));
			}
			catch (err:Error)
			{
				fatal("Unable to send message: " + err.message);
			}
		}
		
		private function sendAck(data:Array, id:String):void
		{
			var packet:Object = {type: Parser.ACK, data: data, nsp: this.channel, id: id}

			try
			{
				webSocket.send(new Encoder().encodeAsString(packet));
			}
			catch (err:Error)
			{
				fatal("Unable to send message: " + err.message);
			}
		}

		public function emit(event:String, msg:Object, callback:Function = null):void
		{
			send(msg, event, callback)
		}
		
		/* DELEGATE flash.events.IEventDispatcher */
		
		public function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void
		{
			_eventDispatcher.addEventListener(type, listener, useCapture, priority, useWeakReference);
		}
		
		public function dispatchEvent(event:Event):Boolean
		{
			return _eventDispatcher.dispatchEvent(event);
		}
		
		public function hasEventListener(type:String):Boolean
		{
			return _eventDispatcher.hasEventListener(type);
		}
		
		public function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void
		{
			_eventDispatcher.removeEventListener(type, listener, useCapture);
		}
		
		public function willTrigger(type:String):Boolean
		{
			return _eventDispatcher.willTrigger(type);
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
			emitBuffered()
			
			this.connected = true;
			this.connecting = false;
			
			_keepaliveTimer = new Timer(heartBeatInterval);
			_keepaliveTimer.addEventListener(TimerEvent.TIMER, keepaliveTimer_timer);
			_keepaliveTimer.start()
			
			var e:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.CONNECT);
			dispatchEvent(e);
		}
		
		private function keepaliveTimer_timer(e:TimerEvent):void
		{
			if (_pongTimer && _pongTimer.running)
				return;
			_pongTimer = new Timer(heartBeatInterval, 1);
			_pongTimer.addEventListener(TimerEvent.TIMER_COMPLETE, pongTimer_timerComplete);
			_pongTimer.start();
			// 2 - ping
			webSocket.send("2");
		}
		
		private function pongTimer_timerComplete(e:TimerEvent):void
		{
			fatal("Server Timed Out!!");
			webSocket.close();
		}
		
		private function _onDisconnect():void
		{
			this.connected = false;
			this.connecting = false;
			var e:FlashSocketEvent = new FlashSocketEvent(FlashSocketEvent.DISCONNECT);
			dispatchEvent(e);
		}
		
		
		public function get eventDispatcher():IEventDispatcher { return _eventDispatcher; }
		
		public function set eventDispatcher(value:IEventDispatcher):void { _eventDispatcher = value; }
		
		public function close():void {
			if (webSocket && (connected || connecting)) {
				webSocket.removeEventListener(WebSocketEvent.MESSAGE, onMessage);
				webSocket.removeEventListener(WebSocketEvent.CLOSE, onClose);
				webSocket.removeEventListener(WebSocketEvent.OPEN, onOpen);
				webSocket.removeEventListener(Event.CLOSE, onClose);
				webSocket.removeEventListener(Event.CONNECT, onConnect);
				webSocket.removeEventListener(IOErrorEvent.IO_ERROR, onIoError);
				webSocket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onSecurityError);
				if (_keepaliveTimer)
					_keepaliveTimer.removeEventListener(TimerEvent.TIMER, keepaliveTimer_timer);
				if (_pongTimer)
					_pongTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, pongTimer_timerComplete);
				webSocket.close();
			}
		}
	}
}
