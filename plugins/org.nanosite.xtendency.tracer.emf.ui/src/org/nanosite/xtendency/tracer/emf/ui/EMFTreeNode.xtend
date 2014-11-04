package org.nanosite.xtendency.tracer.emf.ui

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.util.EcoreUtil.EqualityHelper
import org.eclipse.emf.ecore.EStructuralFeature

class EMFTreeNode extends LazyTreeNode {

	protected EqualityHelper eqHelper

	new(Object value, EqualityHelper eqHelper) {
		super(value)
		this.eqHelper = eqHelper
	}

	override hashCode() {
		if (value instanceof Pair) {
			if (value.value instanceof EObject) {
				val eo = value.value as EObject
				var result = 0
				for (att : eo.eClass.EAllAttributes) {
					if (eo.eIsSet(att)) {
						if (att.EType.name == "EInteger") {
							val intValue = eo.eGet(att) as Integer
							result += intValue + att.name.hashCode
						} else if (att.EType.name == "EString") {
							val stringValue = eo.eGet(att) as String
							result += stringValue.hashCode + att.name.hashCode
						}
					}
				}
				return result
			}else if (value.value instanceof String){
				return value.value.hashCode
			}
		}
		super.hashCode
	}

	override equals(Object object) {
		super.equals(object)
		if ((object instanceof EMFTreeNode && (object as EMFTreeNode).value instanceof Pair) || (object instanceof Pair)) {
			var Pair<Object, Object> otherPair = null
			if (object instanceof EMFTreeNode) {
				otherPair = object.value as Pair<Object, Object>
			} else if (object instanceof Pair) {
				otherPair = object
			}
			if (value instanceof Pair) {
				val thisPair = value as Pair<Object, Object>
				if (thisPair.value instanceof EObject && otherPair.value instanceof EObject &&
					thisPair.key instanceof Pair && otherPair.key instanceof Pair) {
					val thisPair2 = thisPair.key as Pair<Object, Object>
					val otherPair2 = otherPair.key as Pair<Object, Object>
					val sameObject = thisPair.value.equals(otherPair.value) ||
						eqHelper.equals(thisPair.value as EObject, otherPair.value as EObject)
					if (sameObject) {
						println("same object")
					} else {
						println("not same object " + thisPair.value + " and " + otherPair.value)
					}
					if (thisPair2.key instanceof EObject && thisPair2.value instanceof EStructuralFeature &&
						otherPair2.key instanceof EObject && otherPair2.value instanceof EStructuralFeature) {
						val sameFeature = thisPair2.value.equals(otherPair2.value)
						val sameExpression = thisPair2.key.equals(otherPair2.key) ||
							eqHelper.equals(thisPair2.key as EObject, otherPair2.key as EObject)
						println("returning " + (sameFeature && sameExpression && sameObject) + " because feature")
						return sameFeature && sameExpression && sameObject
					} else if ((thisPair2.value == null && otherPair2.value == null) &&
						(thisPair2.key == null && otherPair2.key == null)) {
						println("returning " + sameObject)
						return sameObject
					}
					println("not null and not eobject: " + thisPair2.key + " or " + otherPair2.key)
				}
			}
			println("returning " + super.equals(object) + " in end stmt: value is " + value)
			return super.equals(object)
		}
		println("returning false at very end, object is " + object)
		return false
	}

}
