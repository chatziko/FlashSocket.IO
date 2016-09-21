package com.pnwrain.flashsocket
{
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;

	import com.pnwrain.flashsocket.events.FlashSocketEvent;
	import com.pnwrain.flashsocket.events.EventEmitter;

	///////////////////////////  engine.io  //////////////////////////////
	//
	// This class handles the lower-level (engine.io) communication.
	// They closely ressemble the code of the js client (engine.io-client/lib/socket.js)
	//
	public class Engine extends EventEmitter {

		private var opts:Object;

		private var pingInterval:int;
		private var pingIntervalTimer:int;
		private var pingTimeout:int;
		private var pingTimeoutTimer:int;

		private var writeBuffer:Array = [];
		private var prevBufferLen:int = 0;

		public var upgrading:Boolean = false;
		public var readyState:String;

		public var transport:Transport;
		private var upgrades:Array;


		public function Engine(popts:Object) {
			opts = popts;
			opts.transports = opts.transports ? opts.transports.concat() : ['polling', 'websocket'];
			opts.upgrade = opts.upgrade !== false;

			open();
		}

		private function open():void {
			if(!opts.transports.length)
				throw new Error('no transports');

			readyState = 'opening';

			var transport:Transport = Transport.create(opts.transports[0], opts);
			transport.open();
			setTransport(transport);
		};

		private function setTransport(newtran:Transport):void {
			FlashSocket.log('setting transport ' + newtran.name);

			if(transport) {
				FlashSocket.log('clearing existing transport ' + transport.name);
				transport.removeListener('drain',  onDrain);
				transport.removeListener('packet', onPacket);
				transport.removeListener('error',  onError);
				transport.removeListener('close',  onClose);
			}

			// set up transport
			transport = newtran;

			// set up transport listeners
			transport.on('drain',  onDrain);
			transport.on('packet', onPacket);
			transport.on('error',  onError);
			transport.on('close',  onClose);
		};

		// probes a transport
		private function probe(name:String):void {
			FlashSocket.log('probing transport ', name);
			var newtransport:Transport = Transport.create(name, opts);
			var failed:Boolean = false;

			function onTransportOpen(e:FlashSocketEvent):void {
				if (failed) return;

				FlashSocket.log('probe transport "%s" opened', name);
				newtransport.send([{ type: 'ping', data: 'probe' }]);
				newtransport.once('packet', function(e:FlashSocketEvent):void {
					var msg:Object = e.data;
					if (failed) return;
					if ('pong' == msg.type && 'probe' == msg.data) {
						FlashSocket.log('probe transport "%s" pong', name);
						upgrading = true;
						_emit('upgrading', newtransport);
						if (!newtransport) return;

						FlashSocket.log('pausing current transport "%s"', transport.name);
						transport.pause(function():void {
							if (failed) return;
							if ('closed' == readyState) return;
							FlashSocket.log('changing transport and sending upgrade packet');

							cleanup();

							setTransport(newtransport);
							newtransport.send([{ type: 'upgrade' }]);
							_emit('upgrade', newtransport);
							newtransport = null;
							upgrading = false;
							flush();
						});
					} else {
						FlashSocket.log('probe transport failed', name);
						_emit('upgradeError', { transport: name });
					}
				});
			}

			function freezeTransport():void {
				if (failed) return;

				// Any callback called by transport should be ignored since now
				failed = true;

				cleanup();

				newtransport.close();
				newtransport = null;
			}

			//Handle any error that happens while probing
			function onerror(err:*):void {
				freezeTransport();

				FlashSocket.log('probe transport failed because of error: ', name, err);

				_emit('upgradeError', { transport: name, error: "probe error: "+err });
			}

			function onTransportClose():void {
				onerror("transport closed");
			}

			//When the socket is closed while we're probing
			function onclose():void {
				onerror("socket closed");
			}

			//When the socket is upgraded while we're probing
			function onupgrade(e:FlashSocketEvent):void {
				var to:Transport = e.data;
				if (newtransport && to.name != newtransport.name) {
					FlashSocket.log('"%s" works - aborting "%s"', to.name, newtransport.name);
					freezeTransport();
				}
			}

			//Remove all listeners on the transport and on self
			function cleanup():void {
				newtransport.removeListener('open', onTransportOpen);
				newtransport.removeListener('error', onerror);
				newtransport.removeListener('close', onTransportClose);
				removeListener('close', onclose);
				removeListener('upgrading', onupgrade);
			}

			newtransport.once('open', onTransportOpen);
			newtransport.once('error', onerror);
			newtransport.once('close', onTransportClose);

			once('close', onclose);
			once('upgrading', onupgrade);

			newtransport.open();

		} // proble

		protected function onHandshake(hs:Object):void {
			FlashSocket.log('handshake', hs);

			opts.sid = hs.sid;
			upgrades = hs.upgrades.filter(function(u:*):* { return opts.transports.indexOf(u) != -1 });
			pingTimeout = hs.pingTimeout;
			pingInterval = hs.pingInterval;

			onOpen();
			setPing();
		}

		private function onOpen():void {
			readyState = 'open';
			flush();

			// we check for `readyState` in case an `open`
			// listener already closed the socket
			if ('open' == readyState && opts.upgrade && transport.pausable) {
				FlashSocket.log('starting upgrade probes', upgrades);
				for(var i:int = 0; i < upgrades.length; i++)
					probe(upgrades[i]);
			}
		}

		private function onHeartbeat(timeout:int):void {
			clearTimeout(pingTimeoutTimer);
			pingTimeoutTimer = setTimeout(function ():void {
				if('closed' == readyState)
					return;
				FlashSocket.log("onHeartbeat closing", timeout)
				close();
			}, timeout);
		};

		/**
		 * Pings server every `pingInterval` and expects response * within `pingTimeout` or closes connection.
		 */
		private function setPing():void {
			clearTimeout(pingIntervalTimer);
			pingIntervalTimer = setTimeout(function ():void {
				FlashSocket.log('writing ping packet - expecting pong within ' + pingTimeout + ' ms');
				sendPacket('ping');
				onHeartbeat(pingTimeout);
			}, pingInterval);
		};

		// sends engine.io packet
		public function sendPacket(type:String, data:* = null, options:Object = null, doFlush:Boolean = true):void {
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

		public function flush():void {
			if(!('closed' != readyState && transport.writable && !upgrading && writeBuffer.length))
				return;

			FlashSocket.log('flushing ' + writeBuffer.length + ' packets in socket', writeBuffer);

			transport.send(writeBuffer);
			// keep track of current length of writeBuffer
			// splice writeBuffer and callbackBuffer on `drain`
			prevBufferLen = writeBuffer.length;
		}

		protected function onPacket(e:FlashSocketEvent):void {
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
			if(readyState != 'opening' && readyState != 'open' && readyState != 'closing') {
				FlashSocket.log('packet received with socket readyState ' + readyState);
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
				FlashSocket.log('pong')
				setPing();

			} else if(packet.type == 'error') {
				onError({ data: FlashSocketEvent.IO_ERROR });

			} else if (packet.type == 'message') {
				_emit('data', packet.data);
			}
		}

		private function onDrain(e:FlashSocketEvent):void {
			writeBuffer.splice(0, prevBufferLen);

			// setting prevBufferLen = 0 is very important
			// for example, when upgrading, upgrade packet is sent over,
			// and a nonzero prevBufferLen could cause problems on `drain`
			prevBufferLen = 0;

			if(writeBuffer.length)
				flush();
		};

		private function onClose(e:Object):void {
			if(!('opening' == readyState || 'open' == readyState || 'closing' == readyState)) return;

			var reason:String = e.data;
			FlashSocket.log('socket close with reason: "%s"', reason);

			// clear timers
			clearTimeout(pingIntervalTimer);
			clearTimeout(pingTimeoutTimer);

			// stop event from firing again for transport
			transport.removeListener('close', onClose);

			// ensure transport won't stay open
			transport.close();

			// ignore further transport communication
			transport.removeListener('drain',  onDrain);
			transport.removeListener('packet', onPacket);
			transport.removeListener('error',  onError);

			if('opening' == readyState && opts.transports.length > 1) {
				// try next transport
				opts.transports.shift();
				open();

			 } else {
				// set ready state
				readyState = 'closed';

				// clear session id
				opts.sid = null;

				// emit close event
				_emit('close', reason);

				// clean buffers after, so users can still
				// grab the buffers on `close` event
				writeBuffer = [];
				prevBufferLen = 0;
			}
		};

		private function onError(e:Object):void {
			FlashSocket.log('transport error', e.data)

			// emit 'error' unless we're going to try another transport
			if(!('opening' == readyState && opts.transports.length > 1))
				_emit('error', e.data);

			onClose({ data: 'transport error: '+e.data });
		}

		public function close():void {
			if ('opening' == readyState || 'open' == readyState) {
				readyState = 'closing';

				if (this.writeBuffer.length) {
					this.once('drain', function():void {
						if(upgrading) {
							waitForUpgrade();
						} else {
							close();
						}
					});
				} else if (upgrading) {
					waitForUpgrade();
				} else {
					close();
				}
			}

			function close():void {
				// NOTE:
				// the js client calls onClose immediately at this poing. However,
				// if opening is in progress, transport.close() might not work, we need
				// a handshake first to get the sid! So we just close the transport and wait for it to close
				//
				// onClose({ data: 'forced close' });

				FlashSocket.log('socket closing - telling transport to close');
				transport.close();
			}

			function cleanupAndClose(e:*):void {
				removeListener('upgrade', cleanupAndClose);
				removeListener('upgradeError', cleanupAndClose);
				close();
			}

			function waitForUpgrade():void {
				// wait for upgrade to finish since we can't send packets while pausing a transport
				once('upgrade', cleanupAndClose);
				once('upgradeError', cleanupAndClose);
			}
		}
	}
}
