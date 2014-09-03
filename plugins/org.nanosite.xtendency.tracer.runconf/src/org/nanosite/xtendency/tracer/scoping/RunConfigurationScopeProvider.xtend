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

class RunConfigurationScopeProvider extends XbaseWithAnnotationsBatchScopeProvider {
	private val resolver = SimpleAttributeResolver.newResolver(typeof(String), "name")
	
	def scope_RunConfiguration_function(RunConfiguration ctx, EReference ref) {
		val LinkingDiagnosticMessageProvider p = null
		println("!!!!!! returning " + ctx.clazz.members.filter[it instanceof XtendFunction])
		//Scopes.scopeFor(ctx.clazz.members.filter[it instanceof XtendFunction], [m | QualifiedName.create(m.declaringType.name, (m as XtendFunction).name)], IScope.NULLSCOPE)
		Scopes.scopeFor(ctx.clazz.members.filter[it instanceof XtendFunction], QualifiedName.wrapper(resolver), IScope.NULLSCOPE)
	}
	
	override getScope(EObject context, EReference reference) {
		if (context instanceof RunConfiguration && reference == RunConfPackage.eINSTANCE.runConfiguration_Function){
			return Scopes.scopeFor((context as RunConfiguration).clazz.members.filter[it instanceof XtendFunction], QualifiedName.wrapper(resolver), IScope.NULLSCOPE)
		}else{
			super.getScope(context, reference)
		}
	}
	
}