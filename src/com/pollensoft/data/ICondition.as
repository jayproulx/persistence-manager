package com.pollensoft.data
{
	import mx.core.IUID;

	public interface ICondition extends IUID
	{
		function get parameters():Object;
		function mergeWith(destination:Object):void;
	}
}