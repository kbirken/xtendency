package org.nanosite.xtendency.tracer.core

import java.util.ArrayList
import java.util.List
import java.util.Map
import org.eclipse.xtend.core.xtend.RichStringLiteral
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtend.core.xtend.impl.RichStringLiteralImpl

/**
 * Should be merged with TraceNode
 */
class TraceTreeNode<T> {
	List<TraceTreeNode<T>> children = new ArrayList<TraceTreeNode<T>>
	InputData input
	T output
	
	new(){}

	def getChildren(){
		children
	}
	def getInput(){
		input
	}
	def getOutput(){
		output
	}
	def setInput(InputData i){
		this.input = i
	}
	def setOutput(T o){
		this.output = o
	}
	
	override toString() {
		val in =
			if (input.expression instanceof RichStringLiteral)
				"'" + (input.expression as RichStringLiteral).value.replace("\n", "\\n") + "'"
			else
				input.expression.toString
		"TTN:" + in + "=>" + output
	}
}

@Data class InputData {
	XExpression expression
	Map<String, Object> scope
}
