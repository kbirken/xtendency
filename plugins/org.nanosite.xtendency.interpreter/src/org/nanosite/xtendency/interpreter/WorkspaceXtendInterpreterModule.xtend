package org.nanosite.xtendency.interpreter

import com.google.inject.Binder
import org.eclipse.xtext.service.AbstractGenericModule

class WorkspaceXtendInterpreterModule extends AbstractGenericModule {
	
	def configureSomething(Binder binder){
		binder.bind(IClassManager).to(WorkspaceClassManager)
		binder.bind(IObjectRepresentationStrategy).to(CompiledJavaObjectRepresentationStrategy)
	}
}