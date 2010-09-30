package com.pollensoft.data
{
	public class PersistenceManagerUID
	{
		private static var uid:uint;
		
		public static function get next():uint {
			return uid++;
		}
	}
}