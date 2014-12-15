package org.nanosite.xtendency.interpreter

import java.util.HashMap
import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.AnonymousClass

class StandaloneClassManager implements IClassManager {
	
	protected Map<String, URI> availableClasses = new HashMap<String, URI>
	protected Map<String, AnonymousClass> anonymousClasses = new HashMap
	
	protected ResourceSet rs

	protected ClassLoader classLoader

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
		availableClasses.containsKey(fqn) || anonymousClasses.containsKey(fqn)
	}
	
	override getClassUri(String fqn) {
		availableClasses.get(fqn)
	}
	
	override getResourceSet() {
		rs
	}
	
	override configureClassLoading(ClassLoader injectedClassLoader) {
		this.classLoader = injectedClassLoader
		injectedClassLoader
	}
	
	override getConfiguredClassLoader() {
		classLoader
	}
	
	override getClassForName(String fqn) {
		if (anonymousClasses.containsKey(fqn))
			return anonymousClasses.get(fqn)
		val uri = getClassUri(fqn)
		val r = rs.getResource(uri, true)
		val file = r.contents.head as XtendFile
		val result = file.xtendTypes.findFirst[c | file.package + "." + c.name == fqn]

		result
	}
	
	override addAnonymousClass(String name, AnonymousClass classDef) {
		anonymousClasses.put(name, classDef)
	}
	
}