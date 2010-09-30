package com.pollensoft.data
{
	public interface IPersistable
	{
		// since PersistenceManager relies on fields, we're going to put this all in caps to differentiate.
		// I'm sure this has other uses, but at the moment, I need a way to block primary keys on tables that shouldn't actually have one (or use a composite)
		function getPrimaryKey():String;
	}
}