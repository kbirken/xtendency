package org.nanosite.xtendency.interpreter.tests.input

class BasicCreateMethodClass {
	def create result : new StringBuffer("Something") T15_BasicCreateMethod(String input) {
		result.append("AppendedInBody")
	}
}

class CreateMethodArgClass {
	def create result : new StringBuffer(input) T16_BasicCreateMethod(String input) {
		result.append("AppendedInBody")
	}
}

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

	def set(String newString) {
		this.someString = newString
	}

	def get() {
		someString
	}
}

class ClassWithStaticMember {
	public static String SOMESTRING = "INITIAL"

	def static setStatic(String newString) {
		SOMESTRING = newString
	}

	def setNonStatic(String newString) {
		SOMESTRING = newString
	}

	def static getStatic() {
		SOMESTRING
	}

	def getNonStatic() {
		SOMESTRING
	}
}

class InstanceAndFields21 {

	private String aString = "initialValue"

	def getString() {
		aString
	}

	def setString(String string) {
		aString = string
	}

	def testInstanceAndFields() {
		val other = new InstanceAndFields21
		var result = aString
		result += other.string

		other.string = "changedOther"
		result += string
		result += other.string

		string = "changedThis"
		result += string
		result += other.string

		result += this.equals(other)
		result += this.equals(this)
		result += other.equals(other)

		result += this.toString.contains("InstanceAndFields")
		result += other.toString.contains("InstanceAndFields")
		result += this.toString.equals(other.toString)
		result -> this
	}
}

class JavaSuperClass23 {
	protected String state = "initial"
	
	new(String in){
		state += in
	}
	
	def getOtherString(){
		"otherString"
	}
}

class XtendSuperClass23 extends JavaSuperClass23 {

	new(String in) {
		super(in + "byXtend")
		state += "ByXtend"
	}
	
}

class JavaA {
	def a(){
		"a in A"
	}
}

class JavaB extends JavaA {
	def b(){
		a() + super.a()
	}
}

class JavaExecutionCheckClass {
	def boolean doExecutionCheck(){
		return org.nanosite.xtendency.interpreter.tests.BasicTest::checkInterpreterExecution()
	}
}

class XtendExecutionCheckClass {
	def boolean doExecutionCheck(){
		return org.nanosite.xtendency.interpreter.tests.BasicTest::checkInterpreterExecution()
	}
}

class IndentationClass9Java {

	def someIndentation()'''
		this is right at the beginning
				and two
				«moreIndentation»
			and one
	'''
			
	def moreIndentation()'''
		first line
				second line
	'''
			
	def static invoke(){
		new IndentationClass9Java().someIndentation
	}
}

interface IData35 {
	def String getName()
	def int getIndex()
}

interface IFactory35 {
	
	def IData35 getNewData()
	
	def void setSomething(String in)
	
}
