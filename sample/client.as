package {

import flash.display.Sprite;
import flash.external.ExternalInterface;
import flash.text.TextField;
import flash.utils.ByteArray;

import com.pnwrain.flashsocket.FlashSocket;
import com.pnwrain.flashsocket.events.FlashSocketEvent;


public class client extends Sprite {

	public var socket:FlashSocket;
	public var txt:TextField;

	// log in the TextField, via trace, and with console.log
	//
	public function log(...args):void {
		if(socket)
			args.unshift(socket.transport)

		txt.appendText(args.join(' ') + "\n")

		trace(args.join(' '))

		if(ExternalInterface.available) {
			args.unshift('console.log');
			ExternalInterface.call.apply(ExternalInterface, args)
		}
	}


	public function client() {
		txt = new TextField();
		txt.width = 1000;
		txt.height = 1000;
		addChild(txt);

		FlashSocket.debug = true;

		// connect to the same url as the page we're in
		var url:String = ExternalInterface.call("window.location.href.toString");
		log("connecting to: " + url);

		socket = new FlashSocket(url);

		socket.addEventListener(FlashSocketEvent.CONNECT, function(e:FlashSocketEvent):void {
			log("connected");

			log("sending bar")
			socket.emit('bar', 'foo', function(ba:ByteArray):void {
				log('bar: got back ByteArray: ', ba[0], ba[1]);
			});
		});

		socket.addEventListener('foo', function(e:FlashSocketEvent):void {
			var s:String = e.data[0];
			var cb:Function = e.data[1];

			log("got 'foo' from server with data: " + s);
			log("sending back ByteArray with 2 bytes");

			var ba:ByteArray = new ByteArray();
			ba[0] = 1;
			ba[1] = 2;
			cb(ba);
		})

		socket.addEventListener(FlashSocketEvent.DISCONNECT, function(e:FlashSocketEvent):void {
			log("disconnect");
		});
		socket.addEventListener(FlashSocketEvent.SECURITY_ERROR, function(e:FlashSocketEvent):void {
			log("security error");
		});
		socket.addEventListener(FlashSocketEvent.CONNECT_ERROR, function(e:FlashSocketEvent):void {
			log("connect error");
		});
		socket.addEventListener(FlashSocketEvent.IO_ERROR, function(e:FlashSocketEvent):void {
			log("io error");
		});
		socket.addEventListener(FlashSocketEvent.ERROR, function(e:FlashSocketEvent):void {
			log("error");
		});
	}

} // class
} // package
