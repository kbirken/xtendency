package org.nanosite.xtendency.tracer.emf.ui

import org.eclipse.emf.edit.ui.provider.AdapterFactoryLabelProvider
import org.eclipse.emf.common.notify.AdapterFactory
import org.eclipse.jface.viewers.TreeNode
import org.eclipse.emf.ecore.EStructuralFeature

class EmfLabelProvider extends AdapterFactoryLabelProvider {
	
	new(AdapterFactory adapterFactory) {
		super(adapterFactory)
	}
	
	override getImage(Object element) {
		if (element instanceof TreeNode){
			super.getImage((element.value as Pair<EStructuralFeature, Object>).value)
		}
	}
	
	override getText(Object element) {
		if (element instanceof TreeNode)
			return element.value.label
		else 
			throw new IllegalArgumentException("LabelProvider expected TreeNode, got " + element)
	}
	
	def dispatch getLabel(Pair<EStructuralFeature, Object> p){
		if (p.key != null){
			p.key.name + " : " + (p.value?.toString ?: "null")
		}else{
			p.value.toString
		}
	}
	
	def dispatch getLabel(Object o){
		o.toString
	}
	
	override isLabelProperty(Object element, String property) {
		return false
	}

}