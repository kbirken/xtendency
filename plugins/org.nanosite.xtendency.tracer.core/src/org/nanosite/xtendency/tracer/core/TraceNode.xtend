package org.nanosite.xtendency.tracer.core

import com.google.common.collect.Lists
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.nodemodel.ICompositeNode
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.xbase.XExpression

/**
 * A single node in the tree-like trace structure.
 */
class TraceNode {

	// the Xtend expression which has been evaluated
	XExpression genloc
	
	// the result of the evaluation
	Object result = null

	// inputs are direct parts of the result
	List<TraceNode> inputs = Lists.newArrayList
	
	// impacts are influencing the result, but are not parts
	List<TraceNode> impacts = Lists.newArrayList
		
	new (XExpression genloc) {
		this.genloc = genloc
	} 

	def addInput(TraceNode input) {
		inputs.add(input)
	}

	/**
	 * Switch an input to impact.
	 */
	def input2impact(int idx) {
		impacts.add(inputs.get(idx))
		inputs.remove(idx)	
	}
	
	/**
	 * Remove all inputs except the last one.
	 */
	def allButLast() {
		if (! inputs.empty) {
			val last = inputs.last
			inputs.clear
			inputs.add(last)
		}
	}

	def setResult(Object result) {
		this.result = result
	}

	def getGenloc() {
		genloc
	}

	def dump(int indent) {
		val n = genloc.node
		val loc =
			if (n!=null)
				n.startLine + "-" + n.endLine + "/" + n.offset
			else
				"???"
		val impact = "(" + impacts.map[genloc].join(",") + ")"
		println(("".fill(indent*3) + loc.fill(12) + result.toString).fill(50) + impact)
		
		for(c : inputs) {
			c.dump(indent+1)
		}
	}
	
	def getAnnotatedResult() {
		val n = genloc.node
		val loc = if (n!=null) n.startLine + "-" + n.endLine else "?"
		'''{«loc»:«IF inputs.empty»«result»«ELSE»«FOR i : inputs»«i.annotatedResult»«ENDFOR»«ENDIF»}'''
	}


	def static ICompositeNode getNode (EObject obj) {
		if (obj==null)
			null
		else {
			val n = NodeModelUtils::getNode(obj)
			if (n==null)
				getNode(obj.eContainer)
			else
				n
		}
	}
	

	// TODO: improve this clumsy implementation
	// these are the times when I miss Haskell
	// s ++ (replicate ' ' $ n - (length s))
	def static fill(String s, int n) {
		var i = s.length
		var r = s
		while (i<n) {
			r = r + " "
			i = i + 1			
		}
		r
	}

}