package org.nanosite.xtendency.tracer.core

import org.eclipse.xtext.service.AbstractGenericModule
import com.google.inject.Binder

class StandaloneXtendInterpreterModule extends AbstractGenericModule {
	
	def configureSomething(Binder binder){
		val instance = new StandaloneClassManager
		binder.bind(IClassManager).toInstance(instance)
		binder.bind(StandaloneClassManager).toInstance(instance)
	}
}