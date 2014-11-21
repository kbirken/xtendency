package org.nanosite.xtendency.tracer.core

import org.eclipse.xtext.service.AbstractGenericModule
import com.google.inject.Binder
import com.google.inject.Singleton

class WorkspaceXtendInterpreterModule extends AbstractGenericModule {
	
//	def Class<? extends IClassManager> bindIClassManager() {
//		return WorkspaceClassManager
//	} 
	
	def configureSomething(Binder binder){
//		val instance = new WorkspaceClassManager
//		binder.bind(IClassManager).toInstance(instance)
//		binder.bind(WorkspaceClassManager).toInstance(instance)
		binder.bind(IClassManager).to(WorkspaceClassManager)
		binder.bind(WorkspaceClassManager).in(Singleton)
	}
}