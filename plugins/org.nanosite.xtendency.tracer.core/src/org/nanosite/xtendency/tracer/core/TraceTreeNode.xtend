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
class TraceTreeNode {
	List<TraceTreeNode> children = new ArrayList<TraceTreeNode>
	InputData input
	OutputLocation output
	
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
	def setOutput(OutputLocation o){
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

@Data class OutputLocation{
	int offset
	int length
	String str
	
	override toString() {
		"[" + offset + "/" + length + " '" + str.replace("\n", "\\n") + "']"
	}
}

@Data class InputData {
	XExpression expression
	Map<String, Object> scope
}
