package org.nanosite.xtendency.tracer.core

import org.eclipse.core.resources.IFile
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtext.ui.resource.IResourceSetProvider
import com.google.inject.Inject

class StandaloneXtendInterpreter extends XtendInterpreter {

	def void init (ResourceSet rs) {
		this.rs = rs
		this.availableClasses.clear
	}

	def void addAvailableClass (String classname, URI classResource) {
		// we supply "null" as IFile because in stand-alone mode we do not have a workspace
		availableClasses.put(classname, (null as IFile) -> classResource)
	}
	
	def void addAvailableClass(String classname, XtendFile classContainer){
		availableClasses.put(classname, (null as IFile) -> classContainer.eResource.URI)
	}
}