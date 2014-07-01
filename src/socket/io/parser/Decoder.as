package socket.io.parser
{
import com.adobe.serialization.json.JSON;

/**
 * ...
 * @author Robin Wilding
 */
public class Decoder
{
	
	
	public function decode(obj:String):Object
	{
		var packet:Object = decodeString(obj);
		if (Parser.BINARY_EVENT == packet.type || Parser.BINARY_ACK == packet.type)
		{ // binary packet's json
			throw(new Error("Decoder Does not support binary data"));
		}
		return packet;
	}
	
	public function decodeString(str:String):Object
	{
		str = str.substr(1);
		var c:String;
		var p:Object = {};
		var i:int = 0;
		
		// look up type
		p.type = Number(str.charAt(0));
		
		// look up attachments if type binary
		if (Parser.BINARY_EVENT == p.type || Parser.BINARY_ACK == p.type)
		{
			p.attachments = '';
			while (str.charAt(++i) != '-')
			{
				p.attachments += str.charAt(i);
			}
			p.attachments = Number(p.attachments);
		}
		
		// look up namespace (if any)
		if ('/' == str.charAt(i + 1))
		{
			p.nsp = '';
			while (++i)
			{
				c = str.charAt(i);
				if (',' == c)
					break;
				p.nsp += c;
				if (i + 1 == str.length)
					break;
			}
		}
		else
		{
			p.nsp = '/';
		}
		
		// look up id
		var next:String = str.charAt(i + 1);
		if ('' != next && !isNaN(Number(next)))
		{
			p.id = '';
			while (++i)
			{
				c = str.charAt(i);
				if (null == c || isNaN(Number(c)))
				{
					--i;
					break;
				}
				p.id += str.charAt(i);
				if (i + 1 == str.length)
					break;
			}
			p.id = Number(p.id);
		}
		
		// look up json data
		if (str.charAt(++i))
		{
			try
			{
				var jsonString:String = str.substr(i);
				p.data = com.adobe.serialization.json.JSON.decode(jsonString);
			}
			catch (e:Error)
			{
				p.data = str.substr(i)
				//throw(new Error("Invalid json"));
			}
		}
		
		trace('decoded ' + str + ' as ' + p);
		return p;
	}
}

}