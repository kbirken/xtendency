package org.nanosite.xtendency.tracer.core

import java.io.BufferedReader
import java.io.PrintWriter
import java.io.StringReader
import java.io.StringWriter
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import java.util.Stack
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtext.common.types.JvmExecutable
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XMemberFeatureCall
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationResult
import org.eclipse.xtext.xbase.interpreter.impl.EvaluationException
import org.eclipse.xtext.xbase.interpreter.impl.InterpreterCanceledException

/*
 * Just added the tracing for rich strings for now, should be fused with the existing tracing mechanism.
 */
class TracingInterpreter extends XtendInterpreter {
	
	Set<ITracingProvider<?>> tracingProviders = new HashSet<ITracingProvider<?>>
	
		
	override Object doEvaluate(XExpression expr, IEvaluationContext context, CancelIndicator indicator){
		doEvaluate(expr, context, indicator, true)
	}
	
	def Object doEvaluate(XExpression expr, IEvaluationContext context, CancelIndicator indicator, boolean trace){
		if (trace)
			tracingProviders.filter[canCreateTracePointFor(expr)].forEach[enter(expr, context)]
		val Map<String, Object> ctx = new HashMap<String, Object>
		val result = super.doEvaluate(expr, context, indicator)
		if (trace)
			tracingProviders.filter[canCreateTracePointFor(expr)].forEach[
				exit(expr, context, result)
			]
		return result
	}
	
	def void addTracingProvider(ITracingProvider tp){
		tracingProviders += tp
	}
	
	override def IRichStringExecutor createRichStringExecutor(IEvaluationContext context, CancelIndicator indicator) {
		new TracingRichStringExecutor(this, context, indicator, tracingProviders)
	}
	
	def getTraces(String tracingProviderId) {
		val tp = tracingProviders.findFirst[id == tracingProviderId] 
		tp.rootNode
	}

	def void reset() {
		tracingProviders.forEach[reset]
	}

}
