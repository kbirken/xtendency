package org.nanosite.xtendency.tracer.core

import java.util.HashMap
import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtend.core.xtend.XtendFile

class StandaloneXtendInterpreter extends XtendInterpreter {
	
	protected Map<String, URI> availableClasses = new HashMap<String, URI>
	

	def void init (ResourceSet rs) {
		this.rs = rs
		this.availableClasses.clear
	}

	def void addAvailableClass (String classname, URI classResource) {
		availableClasses.put(classname, classResource)
	}
	
	def void addAvailableClass(String classname, XtendFile classContainer){
		availableClasses.put(classname, classContainer.eResource.URI)
	}
	
	override protected recordClassUse(String fqn) {
		//empty
	}
	
	override protected canInterpretClass(String fqn) {
		availableClasses.containsKey(fqn)
	}
	
	override protected getClassUri(String fqn) {
		availableClasses.get(fqn)
	}
	
}