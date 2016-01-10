// from socket.io-parser/binary.js with as few modifications as possible

package socket.io.parser {

import flash.utils.ByteArray;

public class Binary {
  /**
   * Replaces every Buffer | ArrayBuffer in packet with a numbered placeholder.
   * Anything with blobs or files should be fed through removeBlobs before coming
   * here.
   *
   * @param {Object} packet - socket.io event packet
   * @return {Object} with deconstructed packet and list of buffers
   * @api public
   */

  public static function deconstructPacket(packet:Object):Object {
    var buffers:Array = [];
    var packetData:* = packet.data;

    function _deconstructPacket(data:*):* {
      if (!data) return data;

      if (data is ByteArray) {
        var placeholder:Object = { _placeholder: true, num: buffers.length };
        buffers.push(data);
        return placeholder;
      } else if (data is Array) {
        var newArray:Array = new Array(data.length);
        for (var i:Number = 0; i < data.length; i++) {
          newArray[i] = _deconstructPacket(data[i]);
        }
        return newArray;
      } else if ('object' == typeof data && !(data is Date)) {
        var newObject:Object = {};
        for (var key:String in data) {
          newObject[key] = _deconstructPacket(data[key]);
        }
        return newObject;
      }
      return data;
    }

    var pack:Object = packet;
    pack.data = _deconstructPacket(packetData);
    pack.attachments = buffers.length; // number of binary 'attachments'
    return {packet: pack, buffers: buffers};
  };

  /**
   * Reconstructs a binary packet from its placeholder packet and buffers
   *
   * @param {Object} packet - event packet with placeholders
   * @param {Array} buffers - binary buffers to put in placeholder positions
   * @return {Object} reconstructed packet
   * @api public
   */

  public static function reconstructPacket(packet:Object, buffers:Array):Object {
    var curPlaceHolder:Number = 0;

    function _reconstructPacket(data:*):* {
      if (data && '_placeholder' in data && data._placeholder) {
        var buf:ByteArray = buffers[data.num]; // appropriate buffer (should be natural order anyway)
        return buf;
      } else if (data is Array) {
        for (var i:Number = 0; i < data.length; i++) {
          data[i] = _reconstructPacket(data[i]);
        }
        return data;
      } else if (data && 'object' == typeof data) {
        for (var key:String in data) {
          data[key] = _reconstructPacket(data[key]);
        }
        return data;
      }
      return data;
    }

    packet.data = _reconstructPacket(packet.data);
    packet.attachments = undefined; // no longer useful
    return packet;
  }
}

} // package
