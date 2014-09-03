package org.nanosite.xtendency.tracer.core

import java.util.Map
import java.util.Stack
import org.eclipse.xtext.xbase.XExpression

class XtendTraceContext implements ITraceContext {
	
	// deprecated attributes should be abandoned for other stack
	private int deprecated_offset = 0
	private TraceTreeNode deprecated_resultNode
	private Stack<TraceTreeNode> deprecated_stack = new Stack<TraceTreeNode>
	
	def getOffset() {
		deprecated_offset
	}

	def reset() {
		deprecated_resultNode = null
		deprecated_offset = 0
	}

	override enter() {
		val node = new TraceTreeNode
		deprecated_stack.push(node)
		deprecated_offset
	}
	
	override exit(int previousOffset) {
		val node = deprecated_stack.pop

		if (deprecated_stack.empty())
			deprecated_resultNode = node
		else
			deprecated_stack.peek.children.add(node)

		deprecated_offset = previousOffset + node.output.length
	}
	
	def setInput(XExpression input, Map<String, Object> ctx) {
		deprecated_stack.peek.input = new InputData(input, ctx)
	}

	def setOutput(int offset, String output) {
		deprecated_stack.peek.output = new OutputLocation(offset, output.length, output)
		
		//println("Trace: " + deprecated_stack.peek.output)
	}

	def skip(String output) {
		deprecated_offset = deprecated_offset + output.length
//		println("Skipping " + output.length + " to " + deprecated_offset)
	}
	
	def getTraces() {
		return deprecated_resultNode
	}
}