// Encoder from socket.io-parser/index.js with as few modifications as possible

package socket.io.parser {

import flash.utils.ByteArray;

public class Encoder {

  /**
   * Encode a packet as a single string if non-binary, or as a
   * buffer sequence, depending on packet type.
   *
   * @param {Object} obj - packet object
   * @param {Function} callback - function to handle encodings (likely engine.write)
   * @return Calls callback with Array of encodings
   * @api public
   */

  // socket.io's encoder is asynchronous due to the need to convert Blobs.
  // Ours is synchronous for simplicity
  //
  public function encode(obj:Object):Array {

    if (Parser.BINARY_EVENT == obj.type || Parser.BINARY_ACK == obj.type) {
      return encodeAsBinary(obj);
    }
    else {
      return [encodeAsString(obj)];
    }
  }

  /**
   * Encode packet as string.
   *
   * @param {Object} packet
   * @return {String} encoded
   * @api private
   */

  public function encodeAsString(obj:Object):String {
    var str:String = '';
    var nsp:Boolean = false;

    // first is type
    str += obj.type;

    // attachments if we have them
    if (Parser.BINARY_EVENT == obj.type || Parser.BINARY_ACK == obj.type) {
      str += obj.attachments;
      str += '-';
    }

    // if we have a namespace other than `/`
    // we append it followed by a comma `,`
    if (obj.nsp && '/' != obj.nsp) {
      nsp = true;
      str += obj.nsp;
    }

    // immediately followed by the id
    if (null != obj.id) {
      if (nsp) {
        str += ',';
        nsp = false;
      }
      str += obj.id;
    }

    // json data
    if (null != obj.data) {
      if (nsp) str += ',';
      str += JSON.stringify(obj.data);
    }

    return str;
  }

  /**
   * Encode packet as 'buffer sequence' by removing blobs, and
   * deconstructing packet into object with placeholders and
   * a list of buffers.
   *
   * @param {Object} packet
   * @return {Buffer} encoded
   * @api private
   */

  public function encodeAsBinary(obj:Object):Array {

    var deconstruction:Object = Binary.deconstructPacket(obj);
    var pack:String = encodeAsString(deconstruction.packet);
    var buffers:Array = deconstruction.buffers;

    buffers.unshift(pack); // add packet info to beginning of data list
    return buffers;
  }

}

} // package
