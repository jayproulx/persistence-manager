package com.pollensoft.data
{
	
	public class ConditionSet implements ICondition
	{
		public static const AND:String = " AND ";
		public static const OR:String = " OR ";
		
		public var conditions:Array;
		public var operator:String;
		private var _uid:String;
		
		public function ConditionSet(conditions:Array, operator:String=AND)
		{
			this.conditions = conditions;
			this.operator = operator;
			
			uid = String(PersistenceManagerUID.next);
		}
		
		public function get uid():String {
			return _uid;
		}
		
		public function set uid(value:String):void {
			_uid = value;
		}
		
		public function get parameters():Object {
			var aggregate:Object = new Object();
			
			for each(var c:ICondition in conditions) {
				merge(aggregate, c.parameters);
			}
			
			return aggregate;
		}
		
		public function mergeWith(destination:Object):void {
			merge(destination, parameters);
		}
		
		public static function merge(destination:Object, parameters:Object):void {
			Condition.merge(destination, parameters);
		}
		
		public function toString():String {
			var result:String = "(";
			
			for(var i:int = 0; i < conditions.length; i++) {
				var c:ICondition = conditions[i] as ICondition;
				
				if(i != 0) result += operator;
				
				result += c;
			}
			
			result += ")";
			
			return result;
		}

	}
}