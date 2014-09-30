package org.nanosite.xtendency.tracer.core

import org.eclipse.core.resources.IFile
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet

class StandaloneXtendInterpreter extends XtendInterpreter {

	def void init (ResourceSet rs) {
		this.rs = rs
		this.availableClasses.clear
	}

	def void addAvailableClass (String classname, URI classResource) {
		// we supply "null" as IFile because in stand-alone mode we do not have a workspace
		availableClasses.put(classname, (null as IFile) -> classResource)
	}
	
}