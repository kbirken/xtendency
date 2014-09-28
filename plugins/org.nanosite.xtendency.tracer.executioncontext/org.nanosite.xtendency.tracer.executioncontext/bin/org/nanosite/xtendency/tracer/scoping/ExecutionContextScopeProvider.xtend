package org.nanosite.xtendency.tracer.scoping

import org.eclipse.xtext.xbase.scoping.batch.XbaseBatchScopeProvider
import org.eclipse.xtext.util.SimpleAttributeResolver
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.nanosite.xtendency.tracer.tracingExecutionContext.ExecutionContext
import org.nanosite.xtendency.tracer.tracingExecutionContext.TracingExecutionContextPackage
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.scoping.IScope
import org.eclipse.xtext.scoping.Scopes
import org.eclipse.xtend.core.xtend.XtendMember
import org.eclipse.xtext.naming.SimpleNameProvider

class ExecutionContextScopeProvider extends XbaseBatchScopeProvider {
	private val resolver = [XtendMember m | 
		if (m instanceof XtendFunction){
			val sb = new StringBuilder
			sb.append(m.name)
			sb.append("(")
			for (i : 0..<m.parameters.size){
				sb.append(m.parameters.get(i).parameterType.type.simpleName)
				if (i < m.parameters.size - 1)
					sb.append(", ")
			}
			sb.append(")")
			sb.toString
		}else{
			throw new IllegalArgumentException
		}
	]
	
	private val resolver2 = SimpleAttributeResolver.newResolver(typeof(String), "name")
	
	override getScope(EObject context, EReference reference) {
		if (context instanceof ExecutionContext && reference == TracingExecutionContextPackage.eINSTANCE.executionContext_Function){
			return Scopes.scopeFor((context as ExecutionContext).clazz.members.filter[it instanceof XtendFunction], QualifiedName.wrapper(resolver), IScope.NULLSCOPE)
		}else{
			if (!(context instanceof ExecutionContext))
				println("getscope for context " + context)
			super.getScope(context, reference)
		}
	}
}