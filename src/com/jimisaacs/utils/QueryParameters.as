/**
 name: QueryParameters
 type: dynamic class extends Parameters
 package: com.jimisaacs.utils
 
 description: QueryParameters is an dynamic Object. Please refer to the Parameters class for extensive methods there.
 Properties are added individually,
 with the very versatile add() method,
 by setting the properties array,
 or by setting the queryString.
 All properties may be overwritten.
 This is a way to convert an object to a query string while keeping properties intact.
 You may clear all the properties by the use of the clear() method.
 You may also reset all the properties by the use of the queryString property.
 
 This is NOT equivelant to the URLVariables class!
 Although it is similar.
 Instead, use it as helpful tool to add and retrieve dynamic properties of a desired object.
 It is more like an array but is automatically a queryString and vice versa.
 
 EXAMPLE:
 var params:QueryParameters = new QueryParameters();
 params.name = 'jimisaacs';
 params.height = 200;
 trace(params); // output: 'name=jimisaacs&height=200'
 params.height = '';
 trace(params); // output: 'name=jimisaacs&height'
 params.queryString = 'initials=ji&width=500';
 trace(params.initials); // output: 'ji'
 trace(params); // output: 'initials=ji&width=500'
 
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
	
	import com.jimisaacs.utils.Parameters;
	
	// START CLASS
	public dynamic class QueryParameters extends Parameters {
		
		/*
		* CONSTRUCTOR
		*/
		
		public function QueryParameters(str:String = '') {
			super();
			addStr(str);
		}
		
		/* checks the property before adding it to know whether to convert the value to a string 
		also for names it converts spaces to underscores */			
		override public function addParam(name:*, value:*):void {
			/* set any number of recurring whitespaces to one underscore */
			var pattern:RegExp = /\s+/g; 
			name = String(name).replace(pattern, '_');
			/* encode the value of the property for a URI */
			value = encodeURI(String(value));
			super.addParam(name, value);
		}
		
		/* add enumerable properties provided by a query String (not the String itself) */
		private function addStr(str:String):void {
			var pairs:Array = str.split('&');
			for each(var pairStr:String in pairs) {
				if(pairStr.indexOf('=') >= 0) {
					var pair:Array = pairStr.split('=');
					addParam(pair[0], pair[1]);
				} else if(pairStr.length > 0) {
					addParam(pairStr, '');
				}
			}
		}
		
		/* get or set all enumerable properties as a query string */
		public function get queryString():String {
			var arr:Array = [];
			for(var i:int=0 ; i<super.length ; i++) {
				arr[i] = super.properties[i].name;
				if(super.properties[i].value != '') {
					arr[i] += '=' + super.properties[i].value;
				}
			}
			if(arr.length > 0) {
				return arr.join('&');
			} else {
				return '';
			}
		}
		public function set queryString(str:String):void {
			super.clear();
			addStr(str);
		}
		
		/*
		* PRIMITIVES
		*/
		
		/* when converted to a primitive value always return this class queryString */
		public function valueOf():Object {
			return queryString;
		}
		
		/* when converted to a string always return this class as queryString */
		public function toString():String {
			return queryString;
		}
	}
	// END CLASS
}
// END PACKAGE