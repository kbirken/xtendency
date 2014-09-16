package org.nanosite.xtendency.tracer.core

import org.nanosite.xtendency.tracer.core.ITracingProvider
import org.eclipse.xtext.xbase.XExpression
import java.util.Map
import java.util.Stack
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext

abstract class AbstractTracingProvider<T> implements ITracingProvider<T> {
	
	protected Stack<TraceTreeNode<T>> nodeStack = new Stack<TraceTreeNode<T>>
	
	protected TraceTreeNode<T> resultNode
	
	override enter() {
		val node = new TraceTreeNode
		nodeStack.push(node)
	}
	
	override canCreateTracePointFor(XExpression expr) {
		if (expr.containedInXtendClass){
			canCreateTracePointForExpression(expr)
		}else{
			false
		}
	}
	
	override setOutput(Object output) {
		nodeStack.peek.output = output.createOutputNode
	}
	
	def T createOutputNode(Object output)
	
	def boolean canCreateTracePointForExpression(XExpression expr);
	
	private def boolean isContainedInXtendClass(EObject eo) {
		if (eo == null)
			return false
		if (eo instanceof XtendClass)
			return true
		return eo.eContainer.containedInXtendClass
	}
	
	override setInput(XExpression input, IEvaluationContext ctx) {
		nodeStack.peek.input = new InputData(input, getRelevantContext(input, ctx))
	}
	
	def Map<String, Object> getRelevantContext(XExpression expr, IEvaluationContext context);
	
	override exit() {
		val node = nodeStack.pop

		if (nodeStack.empty())
			resultNode = node
		else
			nodeStack.peek.children.add(node)
	}
	
	override getRootNode() {
		return resultNode
	}
	
	override skip(String output){
		
	}
	
}