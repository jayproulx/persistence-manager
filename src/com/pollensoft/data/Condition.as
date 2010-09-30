package com.pollensoft.data
{
	import mx.core.IUID;
	
	public class Condition implements ICondition
	{
		public static const EQUALS:String = " = ";
		public static const NOT_EQUALS:String = " != ";
		public static const GREATER_THAN:String = " > ";
		public static const LESS_THAN:String = " < ";
		
		public var key:String;
		public var value:*;
		public var check:String;
		
		private var _uid:String;
		
		public function Condition(key:String, value:*, check:String=EQUALS)
		{
			this.key = key;
			this.value = value;
			this.check = check;
			
			uid = String(PersistenceManagerUID.next);
		}
		
		public function get uid():String {
			return _uid;
		}
		
		public function set uid(value:String):void {
			_uid = value;
		}
		
		public function get keyuid():String {
			return ":" + key + uid; 
		}

		public function get parameters():Object {
			var param:Object = new Object();
				param[keyuid] = value;
				
			return param;
		}
		
		public function mergeWith(destination:Object):void {
			merge(destination, parameters);
		}
		
		public static function merge(destination:Object, ... params):void {
			for each(var p:Object in params) {
				for(var i:String in p) {
					destination[i] = p[i];
				}
			}
		}
		
		public function toString():String {
			return key + check + keyuid + " /* " + parameters[keyuid] + " */";
		}

	}
}