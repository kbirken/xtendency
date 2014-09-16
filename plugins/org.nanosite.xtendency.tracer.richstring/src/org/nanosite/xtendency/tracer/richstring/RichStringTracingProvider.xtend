package org.nanosite.xtendency.tracer.richstring

import java.util.Map
import java.util.Stack
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.core.xtend.XtendClass
import org.nanosite.xtendency.tracer.core.TraceTreeNode
import org.eclipse.xtext.xbase.XExpression
import org.nanosite.xtendency.tracer.core.InputData
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import java.util.HashMap
import org.nanosite.xtendency.tracer.core.AbstractTracingProvider

class RichStringTracingProvider extends AbstractTracingProvider<RichStringOutputLocation> {

	public static final String RICH_STRING_TRACING_PROVIDER_ID = "org.nanosite.xtendency.tracer.richstring"

	private int offset = 0

	private Stack<Integer> offsetStack = new Stack<Integer>

	override canCreateTracePointForExpression(XExpression expr) {
		if (expr.richString) {
			return true
		} else {
			if (expr.eContainer != null && expr.eContainer instanceof XExpression) {
				return (expr.eContainer as XExpression).richString
			}
		}
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
		super.enter
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

	override skip(String output) {
		offset = offset + output.length
	}
	
	override createOutputNode(Object output) {
		val strOutput = output.toString
		new RichStringOutputLocation(offsetStack.peek, strOutput.length, strOutput)
	}
	
	override getRelevantContext(XExpression expr, IEvaluationContext context) {
		new HashMap<String, Object>
	}

}
