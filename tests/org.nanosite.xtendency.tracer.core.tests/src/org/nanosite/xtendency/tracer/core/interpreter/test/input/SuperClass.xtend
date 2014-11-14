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
