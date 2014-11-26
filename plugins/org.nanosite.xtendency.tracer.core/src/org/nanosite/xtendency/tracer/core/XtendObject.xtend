package org.nanosite.xtendency.tracer.core

import java.util.HashMap
import java.util.Map

class XtendObject {
	private Map<String, Object> fields = new HashMap<String, Object>
	private String className
	private String id
	
	new(String classFqn){
		this.className = classFqn
		this.id = super.toString.split("@").last
	}
	
	def get(String fieldName){
		fields.get(fieldName)
	}
	
	def set(String fieldName, Object object){
		fields.put(fieldName, object)
	}
	
	def getQualifiedClassName(){
		className
	}
	
	def getSimpleClassName(){
		className.split("\\.").last
	}
	
	override toString() {
		className + "@" + id
	}
	
}