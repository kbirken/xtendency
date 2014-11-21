package org.nanosite.xtendency.tracer.core

import java.util.HashMap
import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtend.core.xtend.XtendFile

class StandaloneClassManager implements IClassManager {
	
	protected Map<String, URI> availableClasses = new HashMap<String, URI>
	
	protected ResourceSet rs

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
	
	override recordClassUse(String fqn) {
		//empty
	}
	
	override canInterpretClass(String fqn) {
		availableClasses.containsKey(fqn)
	}
	
	override getClassUri(String fqn) {
		availableClasses.get(fqn)
	}
	
	override getResourceSet() {
		rs
	}
	
	override configureClassLoading(ClassLoader injectedClassLoader) {
		injectedClassLoader
	}
	
}