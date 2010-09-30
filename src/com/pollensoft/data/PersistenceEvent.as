package com.pollensoft.data
{
	import flash.events.Event;
	
	import mx.collections.ArrayCollection;

	public class PersistenceEvent extends Event
	{
		public static const UPDATE:String = "update";
		public static const INSERT:String = "insert";
		public static const DELETE:String = "delete";
		public static const SELECT:String = "select";
		
		public var table:String;
		public var affected:uint;
		public var results:ArrayCollection; 
		
		public function PersistenceEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
	}
}