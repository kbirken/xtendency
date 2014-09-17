package org.nanosite.xtendency.tracer.emf.ui

import org.eclipse.jface.viewers.TreeNode
import java.util.List

class LazyTreeNode extends TreeNode {
	private ()=>List<TreeNode> childrenFunc
	
	private TreeNode[] children = null
	
	new(Object value) {
		super(value)
	}
	
	def private evaluateChildren(){
		if (children == null && childrenFunc != null){
			children = childrenFunc.apply
		}
	}
	
	override getChildren() {
		evaluateChildren
		return children
	}
	
	override hasChildren() {
		evaluateChildren
		return children != null && children.length != 0
	}
	
	def setChildren(()=>List<TreeNode> childrenFunc) {
		this.childrenFunc = childrenFunc
	}
	
}