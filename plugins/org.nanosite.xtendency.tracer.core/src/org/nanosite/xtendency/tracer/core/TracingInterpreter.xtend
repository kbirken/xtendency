package org.nanosite.xtendency.tracer.core

import java.util.HashMap
import java.util.Map
import java.util.Stack
import org.eclipse.xtend.core.xtend.RichString
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import org.eclipse.xtext.xbase.XAssignment
import org.eclipse.xtext.xbase.XBlockExpression
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XForLoopExpression
import org.eclipse.xtext.xbase.XIfExpression
import org.eclipse.xtext.xbase.XStringLiteral
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext

/*
 * Just added the tracing for rich strings for now, should be fused with the existing tracing mechanism.
 */
class TracingInterpreter extends XtendInterpreter {

	val verbose = false

	Stack<TraceNode> stack = new Stack

	XtendTraceContext tc = new XtendTraceContext
	

	override Object _doEvaluate(RichString rs, IEvaluationContext context, CancelIndicator indicator) {
		val offsetBefore = tc.enter

		val Map<String, Object> ctx = new HashMap<String, Object>

		//		if (context instanceof ChattyEvaluationContext){
		//			context.allMappings.forEach[key, value| ctx.put(key.toString, value)]
		//		}
		val result = super._doEvaluate(rs, context, indicator) as String
		tc.setInput(rs, ctx)
		tc.setOutput(offsetBefore, result)
		tc.exit(offsetBefore)
		
		return result
	}
	
	override def IRichStringExecutor createRichStringExecutor(IEvaluationContext context, CancelIndicator indicator) {
		new TracingRichStringExecutor(tc, this, context, indicator)
	}
	

	override Object _doEvaluate(XBlockExpression expr, IEvaluationContext context, CancelIndicator indicator) {
		val tn = open(expr)
		val result = super._doEvaluate(expr, context, indicator)
		tn.allButLast()
		tn.close(result)
		result
	}

	override Object _doEvaluate(XAssignment expr, IEvaluationContext context, CancelIndicator indicator) {
		val tn = open(expr)
		val result = super._doEvaluate(expr, context, indicator)
		tn.close(result)
		result
	}

	override Object _doEvaluate(XStringLiteral expr, IEvaluationContext context, CancelIndicator indicator) {
		val tn = open(expr)
		val result = super._doEvaluate(expr, context, indicator)
		tn.close(result)
		result
	}

	override Object _doEvaluate(XAbstractFeatureCall expr, IEvaluationContext context, CancelIndicator indicator) {
		val tn = open(expr)
		val result = super._doEvaluate(expr, context, indicator)
		tn.close(result)
		result
	}

	override Object _doEvaluate(XIfExpression expr, IEvaluationContext context, CancelIndicator indicator) {
		val tn = open(expr)
		val result = super._doEvaluate(expr, context, indicator)
		tn.input2impact(0)
		tn.close(result)
		result
	}

	override Object _doEvaluate(XForLoopExpression expr, IEvaluationContext context, CancelIndicator indicator) {
		val tn = open(expr)
		val result = super._doEvaluate(expr, context, indicator)
		tn.close(result)
		result
	}

	def private open(XExpression expr) {
		val tn = new TraceNode(expr)
		stack.push(tn)
		tn
	}

	def private close(TraceNode tn, Object result) {
		if (verbose)
			println("evaluated " + tn.genloc + " to " + result)

		tn.setResult(result)
		stack.pop

		if (stack.isEmpty) {
//			tn.dump(0)
//			println("Annotated result:")
//			println(tn.annotatedResult)
		} else {
			stack.peek.addInput(tn)
		}
	}

	def getTraces() {
		tc.getTraces
	}

	def reset() {
		tc.reset
	}

}
