package org.nanosite.xtendency.tracer.core

import java.util.Stack
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import org.eclipse.xtext.xbase.XAssignment
import org.eclipse.xtext.xbase.XBlockExpression
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XForLoopExpression
import org.eclipse.xtext.xbase.XIfExpression
import org.eclipse.xtext.xbase.XStringLiteral
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import java.util.Map
import java.util.HashMap

/*
 * Just added the tracing for rich strings for now, should be fused with the existing tracing mechanism.
 */
class TracingInterpreter extends XtendInterpreter {

	val verbose = false

	Stack<TraceNode> stack = new Stack

	// deprecated attributes should be abandoned for other stack
	private int deprecated_offset = 0

	private TraceTreeNode deprecated_resultNode

	private Stack<TraceTreeNode> deprecated_stack = new Stack<TraceTreeNode>

	protected override String evaluateRichString(XExpression e, IEvaluationContext context, CancelIndicator indicator) {

		val offsetBefore = deprecated_offset
		val myNode = new TraceTreeNode

		deprecated_stack.push(myNode)

		val Map<String, Object> ctx = new HashMap<String, Object>

		//		if (context instanceof ChattyEvaluationContext){
		//			context.allMappings.forEach[key, value| ctx.put(key.toString, value)]
		//		}
		val result = doEvaluateRichString(e, context, indicator)
		myNode.input = new InputData(e, ctx)
		myNode.output = new OutputLocation(offsetBefore, result.length, result)

		deprecated_stack.pop

		if (deprecated_stack.empty())
			deprecated_resultNode = myNode
		else
			deprecated_stack.peek.children.add(myNode)

		deprecated_offset = offsetBefore + result.length
		return result
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
			tn.dump(0)
			println("Annotated result:")
			println(tn.annotatedResult)
		} else {
			stack.peek.addInput(tn)
		}
	}

	def getTraces() {
		return deprecated_resultNode
	}

	def reset() {
		deprecated_resultNode = null
		deprecated_offset = 0
	}

}
