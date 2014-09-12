package org.nanosite.xtendency.tracer.core

import org.nanosite.xtendency.tracer.core.ITracingProvider
import org.eclipse.xtext.xbase.XExpression
import java.util.Map
import java.util.Stack

abstract class DefaultTracingProvider<T> implements ITracingProvider<T> {
	
	protected Stack<TraceTreeNode<T>> nodeStack = new Stack<TraceTreeNode<T>>
	
	protected TraceTreeNode<T> resultNode
	
	override enter() {
		val node = new TraceTreeNode
		nodeStack.push(node)
	}
	
	override setInput(XExpression input, Map<String, Object> ctx) {
		nodeStack.peek.input = new InputData(input, ctx)
	}
	
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