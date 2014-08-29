package org.nanosite.xtendency.tracer.core

import org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter
import org.eclipse.xtext.xbase.XStringLiteral
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XBinaryOperation
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import java.util.Stack
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XIfExpression
import org.eclipse.xtext.xbase.XBlockExpression
import org.eclipse.xtext.xbase.XAssignment
import org.eclipse.xtext.xbase.XForLoopExpression

class TracingInterpreter extends XbaseInterpreter {
	
	val verbose = false
	
	Stack<TraceNode> stack = new Stack
	
	
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

}
