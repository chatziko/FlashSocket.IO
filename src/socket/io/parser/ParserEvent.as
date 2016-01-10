package socket.io.parser {

import flash.events.Event;

public class ParserEvent extends Event {
  public static const DECODED:String = "decoded";

  public var packet:Object;

  public function ParserEvent(type:String, bubbles:Boolean=true, cancelable:Boolean=false, ppacket:* = null) {
    super(type, bubbles, cancelable);
    packet = ppacket
  }

  public override function clone():Event {
    var event:ParserEvent = new ParserEvent(type, bubbles, cancelable);
    event.packet = packet;
    return event;
  }

  public override function toString():String {
    return formatToString("ParserEvent", "type", "bubbles", "cancelable", "eventPhase", "packet");
  }
}

}
