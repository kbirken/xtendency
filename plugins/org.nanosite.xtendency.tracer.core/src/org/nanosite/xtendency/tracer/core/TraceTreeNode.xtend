package org.nanosite.xtendency.tracer.core

import org.eclipse.xtext.xbase.XExpression
import java.util.Map
import java.util.ArrayList
import java.util.List

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
	
}

@Data class OutputLocation{
	int offset
	int length
	String str
}

@Data class InputData {
	XExpression expression
	Map<String, Object> scope
}
