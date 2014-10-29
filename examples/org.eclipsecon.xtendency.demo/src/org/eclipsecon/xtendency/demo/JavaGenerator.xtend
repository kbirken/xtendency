package org.eclipsecon.xtendency.demo

import org.eclipse.uml2.uml.Class
import org.eclipse.uml2.uml.Package

class JavaGenerator {
	
	private extension MethodGenerator = new MethodGenerator
	
	def writeClassFiles(){
		// load model
		// create skeletons
		// save results
	}
	
	def createClassCode(Package pkg) '''
	
	«FOR clazz : pkg.packagedElements.filter(Class)»
	class «clazz.name» {
		«FOR a : clazz.attributes»
		//TODO: «a.name»
		private «a.type.name» «a.name»;
		«ENDFOR»
		
		«FOR o : clazz.operations»
		«o.createMethodCode»
		«ENDFOR»
	}
	
	«ENDFOR»
	'''
	
}