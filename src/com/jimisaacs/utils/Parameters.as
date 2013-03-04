/**
 name: Parameters
 type: dynamic class extends Proxy
 package: com.jimisaacs.utils
 
 description: Parameters is an dynamic Object.
 Properties are added individually,
 with the very versatile add() method,
 by setting the properties array,
 or by setting the queryString.
 All properties may be overwritten.
 Parameters is more versatile than a Dictionary and an Array because is may be enumerated by index and/or key.
 Not just one or the other.
 
 This is NOT equivelant to the Dictionary class!
 Although it is similar. It is simply a wrapper arround it, and always uses weak keys.
 Instead, use it as a helpful tool to add and retrieve dynamic properties of a desired object.
 Just review the methods, because I will not document them all.
 They are pretty self explanitory, and yet very open ended.
 
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
package com.jimisaacs.utils {
	
	import flash.utils.Dictionary;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
	
	// START CLASS
	public dynamic class Parameters extends Proxy {
		
		/**
		 * VARIABLES
		 */
		
		private var _props:Dictionary;
		
		/**
		 * CONSTRUCTOR
		 */
		
		public function Parameters(... rest) {
			_props = new Dictionary(true);
			add.apply(this, rest);
		}
		
		/* adds an enumerable property */		
		public function addParam(name:*, value:*):void {
			_props[name] = value;
		}
		
		
		/* delete all enumerable properties */
		public function clear():void {
			for(var name:String in _props) {
				_props[name] = null;
				delete _props[name];
			}
		}
		
		/* add enumerable properties provided by an Object (not the Object itself) */
		public function addObj(obj:Object):void {
			for(var prop:String in obj) {
				addParam(prop, obj[prop]);
			}
		}
		
		/* Add any number of instaces */
		public function add(... rest):void {
			for each(var r:Object in rest) {
				addObj(r);
			}
		}
		
		/**
		 * PROPERTIES
		 */
		
		/* gets enumerable props as an indexed complex array */
		// properties
		public function get properties():Array {
			var arr:Array = [];
			for(var name:String in _props) {
				arr.push({name: name, value: _props[name]});
			}
			return arr;
		}
		/* set enumerable props as either an indexed or key array */
		public function set properties(v:Array):void {
			clear();
			addObj(v);
		}
		
		/* return the number of enumerable props */
		// length read-only
		public function get length():int {
			return properties.length;
		}
		
		/**
		 * PROXY OVERRIDES
		 */
		
		override flash_proxy function setProperty(name:*, value:*):void {
			addParam(name, value);
		}
		
		override flash_proxy function deleteProperty(name:*):Boolean {
			if(_props[name]) {
				_props[name] = null;
				delete _props[name];
				return true;
			}
			return false;
		}
		
		override flash_proxy function getProperty(name:*):* {
			// get the value as an index or as the actual name
			if(isNaN(name)) {
				return _props[name];
			} else {
				return properties[name].value;
			}
		}
		
		override flash_proxy function nextNameIndex(index:int):int {
			return (index < length) ? index + 1 : 0;
		}
		
		override flash_proxy function nextName(index:int):String {
			return properties[index - 1].name;
		}
		
		override flash_proxy function nextValue(index:int):* {
			return properties[index - 1].value;
		}
	}
	// END CLASS
}
// END PACKAGE