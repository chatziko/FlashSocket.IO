// port of https://github.com/unshiftio/yeast (MIT license)
//
package com.pnwrain.flashsocket {

	public class Yeast {

		private const length:int = 64

		private var alphabet:Array
		private var map:Object
		private var seed:int = 0
		private var prev:String

		public function Yeast() {

			alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_'.split('')

			// Map each character to its index.
			//
			map = []
			for (var i:int = 0; i < length; i++)
				map[alphabet[i]] = i
		}

		private function encode(num:int):String {
			var encoded:String = ''

			do {
				encoded = alphabet[num % length] + encoded
				num = Math.floor(num / length)
			} while (num > 0)

			return encoded
		}

		public function next():String {
			var now:String = encode(new Date().getTime())

			if (now !== prev) {
				seed = 0
				prev = now
				return now
			} else {
				return now +'.'+ encode(seed++)
			}
		}
	}
}
