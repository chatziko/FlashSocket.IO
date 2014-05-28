/**
 name: URL
 type: class
 package: com.jimisaacs.data
 
 description: URL pares a url string into respective properties.
 Just like the use of javascript's window.location, and my as3 WindowLocation class.
 In general, a URL has this form:
 protocol//host:port/pathname?search#hash
 
 href = Specifies the entire URL.
 protocol = Specifies the beginning of the URL, including the colon.
 host = Specifies the host and domain name, or IP address, of a network host.
 hostname = Specifies the host of the hostname:port portion of the URL.
 port = Specifies the communications port that the server uses.
 pathname = Specifies the URL-path portion of the URL.
 search = Specifies a query.
 hash = Specifies an anchor name in the URL.
 
 author:			Jim Isaacs
 author uri:		http://jimisaacs.com
 
 Copyright (c) 2008 Jim Isaacs
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to 
 deal in the Software without restriction, including without limitation the
 rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 sell copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 IN THE SOFTWARE.
 */

// START PACKAGE
package com.jimisaacs.data {
	
	import com.jimisaacs.utils.QueryParameters;
	
	// START CLASS
	public class URL {
		
		/**
		 * VARIABLES
		 */
		
		private var _protocol:String;
		private var _hostname:String;
		private var _port:String;
		private var _pathname:String;
		private var _search:QueryParameters;
		private var _hash:String;
		
		/**
		 * CONSTRUCTOR
		 */
		
		public function URL(url:String = '')
		{
			parse(url);
		}
		
		/*
		parse
		return Void
		*/
		public function parse(url:String):void {
			if(url.indexOf("//") == -1){
				url = "http://" + url;
			}
			
			var parts:Array = url.split('//');
			_protocol = parts.shift().split(":")[0];
			parts = parts[0].split('/');
			// hostname - host - port
			host = parts.shift();
			// join back together
			var str:String = parts.join('/');
			// the rest, this could be simplified A LOT, just don't feel up to it, let me know if you are
			if(str.indexOf('?') >= 0) {
				if(str.indexOf('#') >= 0) {
					if(str.indexOf('?') < str.indexOf('#')) {
						_pathname = str.substring(0, str.indexOf('?'));
						_search = new QueryParameters(str.substring(str.indexOf('?')+1, str.indexOf('#')));
						_hash = str.substring(str.indexOf('#')+1, str.length);
					} else {
						_pathname = str.substring(0, str.indexOf('#'));
						_search = new QueryParameters(str.substring(str.indexOf('#')+1, str.length).replace('?', ''));
						_hash = '';
					}
				} else {
					_pathname = str.substring(0, str.indexOf('?'));
					_search = new QueryParameters(str.substring(str.indexOf('?')+1, str.length));
					_hash = '';
				}
			} else if(str.indexOf('#') >= 0) {
				_pathname = str.substring(0, str.indexOf('#'));
				_search = new QueryParameters();
				_hash = str.substring(str.indexOf('#')+1, str.length);
			} else {
				_pathname = str.substring(0, str.length);
				_search = new QueryParameters();
				_hash = '';
			}
		}
		
		/**
		 * PROPERTIES
		 */
		
		/*
		href
		return String
		*/
		public function get href():String {
			var str:String = protocol+'//'+host;
			if(pathname != '') {
				str += '/'+pathname;
			}
			if(search != '') {
				str += '?'+search;
			}
			if(hash != '') {
				str += '#'+hash;
			}
			return str;
		}
		public function set href(v:String):void {
			parse(v);
		}
		
		/*
		protocol
		return String
		*/
		public function get protocol():String {
			return _protocol;
		}
		public function set protocol(v:String):void {
			_protocol = v;
		}
		
		/*
		hostname
		return String
		*/
		public function get host():String {
			var str:String = _hostname;
			if(_port != '') {
				str += ':'+_port;
			}
			return str;
		}
		public function set host(v:String):void {
			if(v.indexOf(':') >= 0) {
				_hostname = v.substring(0, v.indexOf(':'));
				_port = v.substring(v.indexOf(':')+1, v.length);
			} else {
				_hostname = v;
				_port = '';
			}
		}
		
		/*
		host
		return String
		*/
		public function get hostname():String {
			return _hostname;
		}
		public function set hostname(v:String):void {
			_hostname = v;
		}
		
		/*
		port
		return String
		*/
		public function get port():String {
			return _port;
		}
		public function set port(v:String):void {
			_port = v;
		}
		
		/*
		pathname
		return String
		*/
		public function get pathname():String {
			return _pathname;
		}
		public function set pathname(v:String):void {
			_pathname = v;
		}
		
		/*
		search
		return String
		*/
		public function get search():String {
			return _search.queryString;
		}
		public function set search(v:String):void {
			_search.queryString = v.replace('?', '');
		}
		
		/*
		parameters
		get the query variables into a dynamic QueryParameters object
		return QueryParameters
		*/
		public function get parameters():QueryParameters {
			return _search;
		}
		public function set parameters(v:*):void {
			_search.add(v);
		}
		
		/*
		hash
		return String
		*/
		public function get hash():String {
			return _hash;
		}
		public function set hash(v:String):void {
			_hash = v.replace('#', '');
		}
		
		/**
		 * PRIMITIVES
		 */
		
		/* when converted to a primitive value always return this class as the href */
		public function valueOf():Object {
			return this.href;
		}
		
		/* when converted to a string always return this class as the href */
		public function toString():String {
			return this.href;
		}
	}
	// END CLASS
}
// END PACKAGE