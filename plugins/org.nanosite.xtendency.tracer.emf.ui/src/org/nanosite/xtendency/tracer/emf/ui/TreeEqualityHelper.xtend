package org.nanosite.xtendency.tracer.emf.ui

import org.eclipse.emf.ecore.util.EcoreUtil.EqualityHelper
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.EAttribute
import org.eclipse.emf.ecore.EReference

class TreeEqualityHelper extends EqualityHelper {
	override boolean haveEqualFeature(EObject eObject1, EObject eObject2, EStructuralFeature feature) {
		if (feature instanceof EAttribute) {

			// If the set states are the same, and the values of the feature are the structurally equal, they are equal.
			//
			val isSet1 = eObject1.eIsSet(feature);
			val isSet2 = eObject2.eIsSet(feature);
			if (isSet1 && isSet2) {
				return haveEqualAttribute(eObject1, eObject2, feature);
			} else {
				return isSet1 == isSet2;
			}

		}else{
			true
		}
	}
}
