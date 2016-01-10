// Decoder from socket.io-parser/index.js with as few modifications as possible

package socket.io.parser {

import com.adobe.serialization.json.JSON;
import flash.events.EventDispatcher;
import flash.utils.ByteArray;

public class Decoder extends EventDispatcher {

  private var reconstructor:BinaryReconstructor;

  /**
   * Decodes an ecoded packet string into packet JSON.
   *
   * @param {String} obj - encoded packet
   * @return {Object} packet
   * @api public
   */

  public function add(obj:*):void {
    var packet:Object;
    if ('string' == typeof obj) {
      packet = decodeString(obj);
      if (Parser.BINARY_EVENT == packet.type || Parser.BINARY_ACK == packet.type) { // binary packet's json
        this.reconstructor = new BinaryReconstructor(packet);

        // no attachments, labeled binary but no binary data to follow
        if (this.reconstructor.reconPack.attachments === 0) {
          dispatchEvent(new ParserEvent(ParserEvent.DECODED, true, false, packet))
        }
      } else { // non-binary full packet
        dispatchEvent(new ParserEvent(ParserEvent.DECODED, true, false, packet))
      }
    }
    else if (obj is ByteArray || obj.base64) { // raw binary data
      if (!this.reconstructor) {
        throw new Error('got binary data when not reconstructing a packet');
      } else {
        packet = this.reconstructor.takeBinaryData(obj);
        if (packet) { // received final buffer
          this.reconstructor = null;
          dispatchEvent(new ParserEvent(ParserEvent.DECODED, true, false, packet))
        }
      }
    }
    else {
      throw new Error('Unknown type: ' + obj);
    }
  };

  /**
   * Decode a packet String (JSON data)
   *
   * @param {String} str
   * @return {Object} packet
   * @api private
   */

  private function decodeString(str:String):Object {
    var p:Object = {};
    var i:Number = 0;
    var c:String;

    // look up type
    p.type = Number(str.charAt(0));
    if (null == Parser.TYPES[p.type]) return error();

    // look up attachments if type binary
    if (Parser.BINARY_EVENT == p.type || Parser.BINARY_ACK == p.type) {
      var buf:String = '';
      while (str.charAt(++i) != '-') {
        buf += str.charAt(i);
        if (i == str.length) break;
      }
      if (isNaN(Number(buf)) || str.charAt(i) != '-') {
        throw new Error('Illegal attachments');
      }
      p.attachments = Number(buf);
    }

    // look up namespace (if any)
    if ('/' == str.charAt(i + 1)) {
      p.nsp = '';
      while (++i) {
        c = str.charAt(i);
        if (',' == c) break;
        p.nsp += c;
        if (i == str.length) break;
      }
    } else {
      p.nsp = '/';
    }

    // look up id
    var next:String = str.charAt(i + 1);
    if ('' !== next && !isNaN(Number(next))) {
      p.id = '';
      while (++i) {
        c = str.charAt(i);
        if (null == c || isNaN(Number(c))) {
          --i;
          break;
        }
        p.id += str.charAt(i);
        if (i == str.length) break;
      }
      p.id = Number(p.id);
    }

    // look up json data
    if (str.charAt(++i)) {
      try {
        p.data = com.adobe.serialization.json.JSON.decode(str.substr(i));
      } catch(e:*) {
        return error();
      }
    }

    return p;
  }

  /**
   * Deallocates a parser's resources
   *
   * @api public
   */

  public function destroy():void {
    if (this.reconstructor) {
      this.reconstructor.finishedReconstruction();
    }
  }

  private function error():Object {
    return {
      type: Parser.ERROR,
      data: 'parser error'
    };
  }
}

} // package

/**
 * A manager of a binary event's 'buffer sequence'. Should
 * be constructed whenever a packet of type BINARY_EVENT is
 * decoded.
 *
 * @param {Object} packet
 * @return {BinaryReconstructor} initialized reconstructor
 * @api private
 */

class BinaryReconstructor {

  import socket.io.parser.Binary;
  import flash.utils.ByteArray;

  public var reconPack:Object;
  public var buffers:Array = [];

  public function BinaryReconstructor(packet:Object) {
    reconPack = packet;
  }

  /**
   * Method to be called when binary data received from connection
   * after a BINARY_EVENT packet.
   *
   * @param {Buffer | ArrayBuffer} binData - the raw binary data received
   * @return {null | Object} returns null if more binary data is expected or
   *   a reconstructed packet object if all buffers have been received.
   * @api private
   */

  public function takeBinaryData(binData:ByteArray):Object {
    this.buffers.push(binData);
    if (this.buffers.length == this.reconPack.attachments) { // done with buffer list
      var packet:Object = Binary.reconstructPacket(this.reconPack, this.buffers);
      this.finishedReconstruction();
      return packet;
    }
    return null;
  };

  /**
   * Cleans up binary packet reconstruction variables.
   *
   * @api private
   */

  public function finishedReconstruction():void {
    this.reconPack = null;
    this.buffers = [];
  };
}

