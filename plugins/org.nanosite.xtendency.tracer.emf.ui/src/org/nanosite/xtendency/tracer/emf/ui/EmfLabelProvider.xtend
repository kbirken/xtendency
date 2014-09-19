package org.nanosite.xtendency.tracer.emf.ui

import org.eclipse.emf.edit.ui.provider.AdapterFactoryLabelProvider
import org.eclipse.emf.common.notify.AdapterFactory
import org.eclipse.jface.viewers.TreeNode
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.EObject

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
	
	def dispatch getLabel(Pair<Pair<EObject, EStructuralFeature>, Object> p){
		val value = p.value
		if (p.key?.value != null){
			p.key.value.name + " : " + if (value instanceof EObject) value.eClass.name else value.toString
		}else{
			if (value instanceof EObject) value.eClass.name else value.toString
		}
	}
	
	def dispatch getLabel(Object o){
		o.toString
	}
	
	override isLabelProperty(Object element, String property) {
		return false
	}

}