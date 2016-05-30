package com.pnwrain.flashsocket.events {

	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;

	public class EventEmitter extends EventDispatcher {

		public var on:Function;
		public var removeListener:Function;

		public function EventEmitter(target:IEventDispatcher = null) {
			super(target);

			on = addEventListener;
			removeListener = removeEventListener;
		}

		public function once(type:String, listener:Function):void {
			var fired:Boolean = false;

			on(type, function handler():void {
				removeListener(type, handler);
				if(!fired) {
					fired = true;
					listener.apply(this, arguments);
				}
			});
		};

		public function emit(type:String, data:Object = null):void {
			var e:Event = new Event(type, data);
			dispatchEvent(e);
		}
	}
}
