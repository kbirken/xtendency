package org.nanosite.xtendency.tracer.emf

import org.nanosite.xtendency.tracer.core.AbstractTracingProvider
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.XExpression
import java.util.HashMap

class EmfTracingProvider extends AbstractTracingProvider<Object> {
	
	override getNodeStack() {
		null
	}
	
	override createOutputNode(Object output) {
		null
	}
	
	override canCreateTracePointForExpression(XExpression expr) {
		false
	}
	
	override getRelevantContext(XExpression expr, IEvaluationContext context) { 
		return new HashMap<String, Object>
	}
	
	override getId() {
		"TODO"
	}
	
	override reset() {
		
	}
	
}