package org.nanosite.xtendency.tracer.core

import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.common.util.URI

interface IClassManager {
	def ResourceSet getResourceSet()
	
	def ClassLoader configureClassLoading(ClassLoader injectedClassLoader)
	def ClassLoader getConfiguredClassLoader()
	
	def void recordClassUse(String fqn)
	
	def boolean canInterpretClass(String fqn)
	
	def URI getClassUri(String fqn)
}