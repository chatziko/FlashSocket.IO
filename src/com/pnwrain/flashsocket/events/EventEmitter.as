package com.pnwrain.flashsocket.events {

	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.utils.Dictionary;

	public class EventEmitter extends EventDispatcher {

		private var _wrapped:Dictionary;

		public function EventEmitter(target:IEventDispatcher = null) {
			super(target);
		}

		public function on(type:String, listener:Function):void {
			addEventListener(type, listener);
		}

		public function once(type:String, listener:Function):void {
			if(!_wrapped)
				_wrapped = new Dictionary(true);

			_wrapped[listener] = function():void {
				if(!(listener in _wrapped)) return;	// just to be sure
				removeListener(type, listener);

				listener.apply(this, arguments);
			};

			on(type, _wrapped[listener]);
		}

		public function removeListener(type:String, listener:Function):void {
			// use the wrapped version, if available
			if(_wrapped && listener in _wrapped) {
				removeEventListener(type, _wrapped[listener]);
				delete _wrapped[listener];
			} else {
				removeEventListener(type, listener);
			}
		}

		public function _emit(type:String, data:Object = null):void {
			var e:FlashSocketEvent = new FlashSocketEvent(type);
			e.data = data;
			dispatchEvent(e);
		}
	}
}
