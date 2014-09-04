package org.nanosite.xtendency.tracer.scoping

import org.eclipse.xtext.scoping.impl.AbstractDeclarativeScopeProvider
import org.nanosite.xtendency.tracer.runConf.RunConfiguration
import org.eclipse.emf.ecore.EReference
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtext.scoping.Scopes
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.util.SimpleAttributeResolver
import org.eclipse.xtext.linking.impl.LinkingDiagnosticMessageProvider
import org.eclipse.xtext.xbase.annotations.typesystem.XbaseWithAnnotationsBatchScopeProvider
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.core.xtend.XtendPackage
import org.nanosite.xtendency.tracer.runConf.RunConfPackage
import org.eclipse.xtext.xbase.scoping.batch.XbaseBatchScopeProvider

class RunConfigurationScopeProvider extends XbaseBatchScopeProvider {
	private val resolver = SimpleAttributeResolver.newResolver(typeof(String), "name")
	
	override getScope(EObject context, EReference reference) {
		if (context instanceof RunConfiguration && reference == RunConfPackage.eINSTANCE.runConfiguration_Function){
			return Scopes.scopeFor((context as RunConfiguration).clazz.members.filter[it instanceof XtendFunction], QualifiedName.wrapper(resolver), IScope.NULLSCOPE)
		}else{
			if (!(context instanceof RunConfiguration))
				println("getscope for context " + context)
			super.getScope(context, reference)
		}
	}
	
}