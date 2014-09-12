package org.nanosite.xtendency.tracer.core

import java.util.HashMap
import java.util.Map
import java.util.Set
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import java.util.HashSet

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
			tracingProviders.filter[canCreateTracePointFor(expr)].forEach[enter]
		val Map<String, Object> ctx = new HashMap<String, Object>
		val result = super.doEvaluate(expr, context, indicator)
		if (trace)
			tracingProviders.filter[canCreateTracePointFor(expr)].forEach[
				setInput(expr, ctx)
				setOutput(result)
				exit
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
		tracingProviders.findFirst[id == tracingProviderId].rootNode
	}

	def void reset() {
		tracingProviders.forEach[reset]
	}

}
