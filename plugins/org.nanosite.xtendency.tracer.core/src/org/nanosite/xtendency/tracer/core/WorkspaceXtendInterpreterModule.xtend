package org.nanosite.xtendency.tracer.core

import org.eclipse.xtext.service.AbstractGenericModule
import com.google.inject.Binder
import com.google.inject.Singleton

class WorkspaceXtendInterpreterModule extends AbstractGenericModule {
	
	def configureSomething(Binder binder){
		binder.bind(IClassManager).to(WorkspaceClassManager)
		binder.bind(IObjectRepresentationStrategy).to(JavaObjectRepresentationStrategy)
	}
}