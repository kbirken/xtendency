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
import org.eclipse.xtend.core.xtend.RichString
import java.util.List
import java.util.ArrayList

class RichStringTracingProvider extends AbstractTracingProvider<RichStringOutputLocation> {

	public static final String RICH_STRING_TRACING_PROVIDER_ID = "org.nanosite.xtendency.tracer.richstring"

	private int offset = 0
	
	private Stack<Stack<TraceTreeNode<RichStringOutputLocation>>> nodeStackStack = new Stack<Stack<TraceTreeNode<RichStringOutputLocation>>>

	private Stack<Stack<Integer>> offsetStackStack = new Stack<Stack<Integer>>
	
	private List<Pair<Object, TraceTreeNode<RichStringOutputLocation>>> functionOutputTreeMap = new ArrayList<Pair<Object, TraceTreeNode<RichStringOutputLocation>>>
	
	def Stack<Integer> getOffsetStack(){
		offsetStackStack.peek
	}

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

	override enter(XExpression input, IEvaluationContext ctx) {
		if (input instanceof RichString){
			nodeStackStack.push(new Stack<TraceTreeNode<RichStringOutputLocation>>)
			offsetStackStack.push(new Stack<Integer>)
			offset = 0
		}
		super.enter(input, ctx)
		offsetStack.push(offset)		
	}

	override exit(XExpression input, IEvaluationContext ctx, Object output) {
		if (functionOutputTreeMap.getNode(output) != null){
			val richStringNode = functionOutputTreeMap.getNode(output)
			richStringNode.addOffset(offsetStack.peek)
			nodeStack.peek.children += richStringNode
		}
		setInput(input, ctx)
		setOutput(output)
		val node = nodeStack.pop
		val previousOffset = offsetStack.pop

		if (nodeStack.empty())
			resultNode = node
		else
			nodeStack.peek.children.add(node)

		offset = previousOffset + node.output.length
		if (input instanceof RichString){
			val lastNodeStack = nodeStackStack.pop
			val lastOffsetStack = offsetStackStack.pop
			functionOutputTreeMap += new Pair(output, node)
		}
	}
	
	def private TraceTreeNode<RichStringOutputLocation> getNode(List<Pair<Object, TraceTreeNode<RichStringOutputLocation>>> map, Object output){
		for (p : map){
			if (p.key === output){
				return p.value
			}
		}
		return null
	}
	
	def addOffset(TraceTreeNode<RichStringOutputLocation> tree, int offset){
		tree.output.offset = tree.output.offset + offset
		for (c : tree.children){
			c.addOffset(offset)
		}
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
	
	override getNodeStack() {
		nodeStackStack.peek
	}

}
