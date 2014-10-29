package org.eclipsecon.xtendency.demo

import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EcoreFactory
import org.eclipse.emf.ecore.EAttribute

class EcoreGenerator {
	
	def void transformAndSaveModel(String uri){
		// load model,
		// transform
		// store result
	}
	
	def transformPackage(org.eclipse.uml2.uml.Package pkg){
		val result = EcoreFactory.eINSTANCE.createEPackage
		result.name = pkg.name
		for (c : pkg.packagedElements.filter(org.eclipse.uml2.uml.Class)){
			result.EClassifiers += c.transformClass
		}
		result
	}
	
	def EClass create result : EcoreFactory.eINSTANCE.createEClass transformClass(org.eclipse.uml2.uml.Class clazz){
		result.name = clazz.name
		if (!clazz.redefinedClassifiers.empty)
			result.ESuperTypes += (clazz.redefinedClassifiers.head as org.eclipse.uml2.uml.Class).transformClass
		for (prop : clazz.attributes){
			result.EStructuralFeatures += prop.transformAttribute
		}
		
	}
	
	def EAttribute transformAttribute(org.eclipse.uml2.uml.Property prop){
		//TODO
		val result = EcoreFactory.eINSTANCE.createEAttribute
		result.name = prop.name
		result
	}
}