package com.pollensoft.data
{
	import flash.data.SQLConnection;
	import flash.data.SQLMode;
	import flash.data.SQLStatement;
	import flash.errors.SQLError;
	import flash.filesystem.File;
	import flash.net.Responder;
	import flash.utils.Dictionary;
	import flash.utils.describeType;
	import flash.utils.getQualifiedClassName;
	
	import mx.collections.ArrayCollection;
	import mx.utils.ObjectUtil;
	import mx.utils.StringUtil;
	
	public class PersistenceManager
	{
		private static const DB_NAME:String = "PersistenceManager"
		private static const PM_DB_FILE:String = DB_NAME + ".db";
		private static const DEBUG:Boolean = false;
		
		public static const MERGE:String = "merge";
		public static const REPLACE:String = "replace";
		public static const APPEND:String = "append";
		
		private static var createdTables:Dictionary = new Dictionary(true);
		private static var tableDefinitions:Dictionary = new Dictionary(true);
		private static var fieldList:Dictionary = new Dictionary(true);
		private static var tableNames:Dictionary = new Dictionary(true);
		
		private static var connection:SQLConnection;
		
		public static function persist(definition:Class, collection:ArrayCollection, primaryKey:String, type:String=MERGE):void {
			if(type == REPLACE) {
				purge(definition);
			}
			
			for each(var o:Object in collection) {
				persistOne(definition, o, primaryKey, type);
			}
		}
		
		public static function persistOne(definition:Class, object:Object, primaryKey:String, type:String=MERGE):void {
			var inst:PersistenceManager = getInstance();

			inst.createTable(definition, primaryKey);

			if(type == REPLACE || type == MERGE) {
				if(type == MERGE && primaryKey == null) {
					throw new Error("MERGE needs a primaryKey provided");
				}
				
				if(recordExists(definition, object, primaryKey)) {
					inst.updateObject(definition, object, primaryKey);
				} else {
					inst.insertObject(definition, object);
				}
			} else if(type == APPEND) {
				inst.insertObject(definition, object);
			}
		}
		
		public static function findOne(definition:Class, key:String, value:String):Array {
			var inst:PersistenceManager = getInstance();

			var statement:SQLStatement = new SQLStatement();
				statement.sqlConnection = connection;
				statement.itemClass = definition;
				statement.text = StringUtil.substitute("SELECT * FROM {0} where {1} = :value", inst.getTableName(definition), key);
				statement.parameters[":value"] = value;
				statement.execute();
			
			if(DEBUG) trace("Find one: " + statement.text);
			
			return statement.getResult().data;
		}
		
		public static function recordExists(definition:Class, object:Object, primaryKey:String):Boolean {
			var inst:PersistenceManager = getInstance();
			
			var condition:Condition = new Condition(primaryKey, object[primaryKey]);
			
			var statement:SQLStatement = new SQLStatement();
				statement.sqlConnection = connection;
				statement.text = StringUtil.substitute("SELECT COUNT({1}) as numRecords FROM {0} WHERE " + condition, inst.getTableName(definition), primaryKey);
				condition.mergeWith(statement.parameters);
				
				// if(DEBUG) trace("Record exists: " + statement.text, ObjectUtil.toString(statement.parameters));
				
				statement.execute();
			
			var d:Array = statement.getResult().data;
			
			return d != null && d.length > 0 && d[0].numRecords > 0;
		}
		
		public static function findAll(definition:Class):Array {
			var inst:PersistenceManager = getInstance();

			var statement:SQLStatement = new SQLStatement();
				statement.sqlConnection = connection;
				statement.itemClass = definition;
				statement.text = "SELECT * FROM " + inst.getTableName(definition);

			try {
				statement.execute();
			} catch (error:SQLError) {
				trace("Find All error: " + error, statement.text);
				return null;
			}
				
			if(DEBUG) trace("Find all: " + statement.text);
			return statement.getResult().data;
		}
		
		public static function find(definition:Class, criteria:ICondition):Array {
			var inst:PersistenceManager = getInstance();

			var statement:SQLStatement = new SQLStatement();
				statement.sqlConnection = connection;
				statement.itemClass = definition;
				statement.text = "SELECT * FROM " + inst.getTableName(definition) + " WHERE " + criteria;
				criteria.mergeWith(statement.parameters);

			try {
				statement.execute();
			} catch (error:SQLError) {
				trace("Find Error: " + error, statement.text);
				
				return null;
			}
			
			if(DEBUG) trace("Find : " + statement.text);
			return statement.getResult().data;
		}
		
		public static function purge(definition:Class=null):void {
			var inst:PersistenceManager = getInstance();

			if(definition == null) {
				inst.deleteDatabase();
				
				return;
			}
			
			var table:String = inst.getTableName(definition);

			if(createdTables[table] == null || createdTables[table] == false) return; 
			
			var statement:SQLStatement = new SQLStatement();
				statement.sqlConnection = connection;
				statement.text = "DROP TABLE IF EXISTS " + table;
				statement.execute();
				
			createdTables[table] = true;
				
			if(DEBUG) trace("Purging table: " + statement.text);
		}
		
		public static function deleteRecords(definition:Class, primaryKey:String, value:*):void {
			var inst:PersistenceManager = getInstance();
			
			// in case it doesn't exist
			inst.createTable(definition, primaryKey);
			
			inst.deleteObjects(definition, primaryKey, value);
		}
		
		/******************************** DB COMMUNICATION  ********************************/
		
		private function createDatabase():void {
			var dbPath:File = File.applicationStorageDirectory.resolvePath(PM_DB_FILE);
			
			if(DEBUG) trace("Create Database: " + dbPath.nativePath);
			
			connection = new SQLConnection();
			connection.open(dbPath, SQLMode.CREATE);
		}
		
		private function deleteDatabase():void {
			connection.close(new Responder(connectionClosedAndDelete, closeConnectionFault));
		}
		
		private function connectionClosedAndDelete(data:Object):void {
			var dbPath:File = File.applicationStorageDirectory.resolvePath(PM_DB_FILE);
			
			instance = null;
			
			dbPath.deleteFile();
		}
		
		private function closeConnectionFault(info:Object):void {
			
			instance = null;
			trace("PersistenceManager deleteDatabase Fault: " + ObjectUtil.toString(info));
		}
		
		private function fieldToValue(input:*, index:int, array:Array):Boolean {
			array[index] = ":" + input;
			
			return true;
		}
		
		private function insertObject(definition:Class, object:Object):void {
			var fields:Array = getFields(definition);
			var values:Array = ObjectUtil.copy(fields) as Array;
				values.every(fieldToValue);
				
			var sql:String = "INSERT INTO " + getTableName(definition) + " (" + fields.join(", ") + ") VALUES (" + values.join(", ") + ")";
			
			var stmt:SQLStatement = new SQLStatement();
				stmt.sqlConnection = connection;
				stmt.text = sql;
			
				for each(var f:String in fields) {
					stmt.parameters[":" + f] = object[f];
				}
				
				
			if(DEBUG) trace("Insert object: " + sql);
			
				stmt.execute();
		}
		
		private function updateObject(definition:Class, object:Object, primaryKey:String):void {
			var fields:Array = getFields(definition);
			var values:Array = ObjectUtil.copy(fields) as Array;
				values.every(fieldToValue);
			var sql:String = StringUtil.substitute("UPDATE {0} SET ", getTableName(definition));

				var first:Boolean = true;			
				for each(var f:String in fields) {
					if(!first) sql += ", ";
					
					sql += f + " = :" + f;
							
					first = false;
				}
				
				sql += " WHERE " + primaryKey + " = :" + primaryKey;

			var stmt:SQLStatement = new SQLStatement();
				stmt.sqlConnection = connection;
				stmt.text = sql;
			
				for each(var f1:String in fields) {
					stmt.parameters[":" + f1] = object[f1];
				}
				
				if(DEBUG) trace("Updating record: " + sql);
				
				stmt.execute();
		}
		
		private function deleteObject(definition:Class, object:Object, primaryKey:String):void {
			var sql:String = StringUtil.substitute("DELETE FROM {0} WHERE {1} = :{1}", getTableName(definition), primaryKey);
			if(DEBUG) trace("Deleting record: " + sql);			
			var stmt:SQLStatement = new SQLStatement();
				stmt.sqlConnection = connection;
				stmt.text = sql;
				stmt.parameters[":" + primaryKey] = object[primaryKey];
				stmt.execute();
		}
		
		private function deleteObjects(definition:Class, primaryKey:String, value:*):void {
			var sql:String = StringUtil.substitute("DELETE FROM {0} WHERE {1} = :{1}", getTableName(definition), primaryKey);
			if(DEBUG) trace("Deleting records: " + sql);			
			var stmt:SQLStatement = new SQLStatement();
				stmt.sqlConnection = connection;
				stmt.text = sql;
				stmt.parameters[":" + primaryKey] = value;
				stmt.execute();
		}

		private function getFields(definition:Class):Array {
			if(fieldList[definition] != null) {
				return fieldList[definition];
			}
			
			var ci:Object = ObjectUtil.getClassInfo(definition, ["prototype"]);
			var f:Array = [];
			
			for each(var i:String in ci.properties) {
				f.push(i);
			}
			
			fieldList[definition] = f;
			
			return f;
		}
		
		private function getTableName(definition:*):String {
			if(tableNames[definition] != null) {
				return tableNames[definition];
			}
			
			var d:Object = definition is Class ? new definition() : definition;
			var n:String = getQualifiedClassName(d); 
			
			while(n.match(/\W/)) {
				n = n.replace(/\W/, "");
			} 
							
			d = null;
			
			tableNames[definition] = n;
			
			return n;
		}
		
		private function createTable(definition:Class, primaryKey:String):void {
			var table:String = getTableName(definition);
			
			if(createdTables[table] != null && createdTables[table]) return;
			
			var sql:String = "CREATE TABLE IF NOT EXISTS " + table + " (" + getColumnDefinitions(definition, primaryKey).join(", ") + ")";
			if(DEBUG) trace("Creating table: " + sql);
			var stmt:SQLStatement = new SQLStatement();
				stmt.sqlConnection = connection;
				stmt.text = sql;
				stmt.execute();
				
			createdTables[table] = true;
		}
		
		private function getColumnDefinitions(definition:Class, primaryKey:String):Array {
			if(tableDefinitions[definition] != null) {
				return tableDefinitions[definition];
			}
			
			var columns:Array = [];
			var sample:Object = new definition();
			var dt:XML = flash.utils.describeType(sample);
			var accessors:XMLList = dt..accessor;
			var variables:XMLList = dt..variable;
			var d:ColumnDefinition;
			
			// if(DEBUG) trace("Accessors: " + ObjectUtil.toString(dt));
			for each(var accessor:XML in accessors) {
				d = new ColumnDefinition(accessor.@name, accessor.@type, sample, definition, isPrimaryKey(sample, accessor.@name, primaryKey));
				
				if(d.toString().length == 0) continue;
				
				columns.push(d);
			}
			
			for each(var variable:XML in variables) {
				d = new ColumnDefinition(variable.@name, variable.@type, sample, definition, isPrimaryKey(sample, variable.@name, primaryKey));
				
				if(d.toString().length == 0) continue;
				
				columns.push(d);
			}
			
			tableDefinitions[definition] = columns;
			
			return columns;
		}
		
		private function isPrimaryKey(sample:Object, field:String, primaryKey:String):Boolean {
			var ispk:Boolean = false;
			
			if(sample is IPersistable) {
				if(IPersistable(sample).getPrimaryKey() == field) {
					ispk = true;
				}
			} else if(field == primaryKey) {
				ispk = true;
			}
			
			return ispk;
		}
		
		/******************************** SINGLETON METHODS ********************************/ 
        private static var instance : PersistenceManager;
     
        public function PersistenceManager() 
        {   
           if ( instance != null )
           {
              throw new Error("You can only have one instance of the PersistenceManager");
           }
           
           createDatabase();
            
           instance = this;
        }
        
        public static function getInstance() : PersistenceManager 
        {
           if ( instance == null )
               instance = new PersistenceManager();
               
           return instance;
        }
		
	}
}
	import mx.utils.StringUtil;
	

class ColumnDefinition {
	public var field:String;
	public var typeString:String;
	public var source:Object;
	public var definition:Class;
	public var primaryKey:Boolean;
	
	private static const NUMBER_TYPE:String = "NUMERIC";
	private static const DATE_TYPE:String = "DATE";
	private static const BOOLEAN_TYPE:String = "BOOLEAN";
	private static const XML_TYPE:String = "XML";
	private static const XMLLIST_TYPE:String = "XMLLIST";
	private static const OBJECT_TYPE:String = "OBJECT";
	private static const STRING_TYPE:String = "TEXT";

	public function ColumnDefinition(field:String, type:String, source:Object, definition:Class, primaryKey:Boolean) {
		this.field = field;
		this.typeString = type;
		this.source = source;
		this.definition = definition;
		
		this.primaryKey = primaryKey;
	}
	
	public function get type():String {
		if(source[field] is Number) return NUMBER_TYPE;
		if(typeString == "Date") return DATE_TYPE;
		if(source[field] is Boolean) return BOOLEAN_TYPE;
		if(source[field] is XML) return XML_TYPE;
		if(source[field] is XMLList) return XMLLIST_TYPE;
		if(source[field] is Object && !(source[field] is String)) return OBJECT_TYPE;
		
		return STRING_TYPE;
	}
	
	public function toString():String {
		return StringUtil.trim(field + " " + type + (primaryKey ? " PRIMARY KEY" : ""));
	}
}
