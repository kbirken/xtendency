package org.nanosite.xtendency.tracer.core.interpreter.test.input

class SuperClass {
	def doSomething() {
		"From the SuperClass. "
	}
}

class SubClass extends SuperClass {

	override doSomething() {
		"From the SubClass and " + super.doSomething
	}
}

class ClassWithPublicMember {
	public String someString = "initial"
	
	def set(String newString){
		this.someString = newString
	}
	
	def get(){
		someString
	}
}

class ClassWithStaticMember {
	public static String SOMESTRING = "INITIAL"
	
	def static setStatic(String newString){
		SOMESTRING = newString
	}
	
	def setNonStatic(String newString){
		SOMESTRING = newString
	}
	
	def static getStatic(){
		SOMESTRING
	}

	def getNonStatic(){
		SOMESTRING
	}
}
