package org.nanosite.xtendency.tracer.core

import org.nanosite.xtendency.tracer.core.ITracingProvider
import org.eclipse.xtext.xbase.XExpression
import java.util.Map
import java.util.Stack
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.core.xtend.XtendClass

class RichStringTracingProvider implements ITracingProvider<RichStringOutputLocation> {

	public static final String RICH_STRING_TRACING_PROVIDER_ID = "org.nanosite.xtendency.tracer.richstring"

	private int offset = 0
	private TraceTreeNode<RichStringOutputLocation> resultNode
	private Stack<TraceTreeNode<RichStringOutputLocation>> nodeStack = new Stack<TraceTreeNode<RichStringOutputLocation>>
	private Stack<Integer> offsetStack = new Stack<Integer>

	override canCreateTracePointFor(XExpression expr) {
		if (expr.containedInXtendClass) {
			if (expr.richString) {
				return true
			} else {
				if (expr.eContainer != null && expr.eContainer instanceof XExpression) {
					return (expr.eContainer as XExpression).richString
				}
			}
		} else {
			false
		}
	}

	private def boolean isContainedInXtendClass(EObject eo) {
		if (eo == null)
			return false
		if (eo instanceof XtendClass)
			return true
		return eo.eContainer.containedInXtendClass
	}

	private def boolean isRichString(XExpression expr) {
		expr.class.simpleName.startsWith("RichString")
	}

	override getId() {
		return RICH_STRING_TRACING_PROVIDER_ID;
	}

	def getOffset() {
		offset
	}

	override reset() {
		resultNode = null
		offset = 0
	}

	override enter() {
		val node = new TraceTreeNode
		nodeStack.push(node)
		offsetStack.push(offset)
	}

	override exit() {
		val node = nodeStack.pop
		val previousOffset = offsetStack.pop

		if (nodeStack.empty())
			resultNode = node
		else
			nodeStack.peek.children.add(node)

		offset = previousOffset + node.output.length
	}

	override setInput(XExpression input, Map<String, Object> ctx) {
		nodeStack.peek.input = new InputData(input, ctx)
	}

	override setOutput(Object output) {
		val strOutput = output.toString

		nodeStack.peek.output = new RichStringOutputLocation(offsetStack.peek, strOutput.length, strOutput)
	}

	override skip(String output) {
		offset = offset + output.length
	}

	override getRootNode() {
		return resultNode
	}

}
