package org.nanosite.xtendency.interpreter

import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.common.util.URI
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.xtend.core.xtend.AnonymousClass

interface IClassManager {
	def ResourceSet getResourceSet()
	
	def ClassLoader configureClassLoading(ClassLoader injectedClassLoader)
	def ClassLoader getConfiguredClassLoader()
	
	def void recordClassUse(String fqn)
	
	def boolean canInterpretClass(String fqn)
	
	def URI getClassUri(String fqn)
	
	def XtendTypeDeclaration getClassForName(String fqn)
	
	def void addAnonymousClass(String name, AnonymousClass classDef)
}