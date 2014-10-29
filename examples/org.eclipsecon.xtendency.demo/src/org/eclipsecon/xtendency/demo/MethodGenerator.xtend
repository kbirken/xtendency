package org.eclipsecon.xtendency.demo

import org.eclipse.uml2.uml.Operation

class MethodGenerator {
	def createMethodCode(Operation op) '''
	//TODO: operation «op.name»
	def «op.name»(«FOR p : op.ownedParameters SEPARATOR ', '»«p.type.name» «p.name»«ENDFOR»){
		TODO
	}
	'''
}