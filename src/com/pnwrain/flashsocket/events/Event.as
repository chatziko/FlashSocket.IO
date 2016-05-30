// Simple event to be used with EventEmitter

package com.pnwrain.flashsocket.events {

	import flash.events.Event;

	public class Event extends flash.events.Event {

		public var data:*;

		public function Event(type:String, pdata:* = null) {
			super(type);
			data = pdata;
		}
	}
}
