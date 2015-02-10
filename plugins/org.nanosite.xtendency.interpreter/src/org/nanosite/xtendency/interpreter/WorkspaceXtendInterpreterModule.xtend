package org.nanosite.xtendency.interpreter

import com.google.inject.Binder
import org.eclipse.xtext.service.AbstractGenericModule
import org.nanosite.xtendency.interpreter.IObjectRepresentationStrategy
import org.nanosite.xtendency.interpreter.ors.javassist.JavassistClassObjectRepresentationStrategy

class WorkspaceXtendInterpreterModule extends AbstractGenericModule {
	
	def configureSomething(Binder binder){
		binder.bind(IClassManager).to(WorkspaceClassManager)
		binder.bind(IObjectRepresentationStrategy).to(JavassistClassObjectRepresentationStrategy)
	}
}