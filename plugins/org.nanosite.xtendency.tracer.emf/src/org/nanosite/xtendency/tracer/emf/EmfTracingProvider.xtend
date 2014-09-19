package org.nanosite.xtendency.tracer.emf

import org.nanosite.xtendency.tracer.core.AbstractTracingProvider
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.XExpression
import java.util.HashMap
import java.util.Map
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.nanosite.xtendency.tracer.core.ITracingProvider
import org.nanosite.xtendency.tracer.core.TraceTreeNode
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtext.xbase.XFeatureCall
import org.eclipse.xtext.xbase.XMemberFeatureCall
import java.util.Stack
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtext.common.types.JvmOperation
import java.util.HashSet
import java.util.ArrayList
import org.eclipse.xtext.xbase.XAssignment
import java.util.Set
import org.eclipse.emf.ecore.EClass
import org.eclipse.xtext.xbase.XbasePackage

class EmfTracingProvider implements ITracingProvider<Map<Pair<EObject, EStructuralFeature>, List<Pair<XExpression, Map<String, Object>>>>> {
	public static final String EMF_TRACING_PROVIDER_ID = "org.nanosite.xtendency.tracer.emf"

	private Map<Pair<EObject, EStructuralFeature>, List<Pair<XExpression, Map<String, Object>>>> modelChanges

	private Stack<Map<XExpression, Object>> lastEvaluated = new Stack<Map<XExpression, Object>>

	private Set<EClass> trackedExpressions = #{XbasePackage.Literals.XASSIGNMENT}

	new() {
		modelChanges = new HashMap<Pair<EObject, EStructuralFeature>, List<Pair<XExpression, Map<String, Object>>>>
	}

	override canCreateTracePointFor(XExpression expr) {
		expr.containedInXtendClass
	}

	private def boolean isContainedInXtendClass(EObject eo) {
		if (eo == null)
			return false
		if (eo instanceof XtendClass)
			return true
		return eo.eContainer.containedInXtendClass
	}

	override enter(XExpression input, IEvaluationContext ctx) {
		if (input.eContainer instanceof XtendFunction) {
			lastEvaluated.push(new HashMap<XExpression, Object>)
		}
	}

	override exit(XExpression expr, IEvaluationContext ctx, Object output) {
//		if (expr instanceof XMemberFeatureCall) {
//			val rec = expr.actualReceiver
//			if (!lastEvaluated.peek.containsKey(rec))
//				throw new IllegalStateException
//			val receiverObj = if(rec == null) null else lastEvaluated.peek.get(rec)
//
//			val feat = expr.feature
//			if (receiverObj != null && receiverObj instanceof EObject && feat instanceof JvmOperation) {
//				logChange(feat as JvmOperation, receiverObj as EObject, expr)
//			}
//		} 
		if (expr instanceof XAssignment) {
			if (expr.feature instanceof JvmOperation) {
				if (!lastEvaluated.peek.containsKey(expr.assignable))
					throw new IllegalStateException
				val receiverObj = lastEvaluated.peek.get(expr.assignable)
				if (receiverObj != null && receiverObj instanceof EObject){
					logChange(expr.feature as JvmOperation, receiverObj as EObject, expr, ctx)
				}
			}
		}
		if (trackedExpressions.contains(expr.eContainer.eClass)) {
			lastEvaluated.peek.put(expr, output)
		}
		if (expr.eContainer instanceof XtendFunction)
			lastEvaluated.pop
	}

	def logChange(JvmOperation op, EObject receiverObj, XExpression expr, IEvaluationContext ctx) {
		if (op.simpleName.startsWith("set")) {
			val sfName = op.simpleName.substring(3)
			var sf = receiverObj.eClass.EAllStructuralFeatures.findFirst[name == sfName || name == sfName.toFirstLower]
			if (sf != null) {
				val ctxMap = if (ctx instanceof ChattyEvaluationContext) ctx.contents else new HashMap<String, Object>
				modelChanges.safeGet(receiverObj -> sf).add(expr -> ctxMap)
			}
		}
	}

	def List<Pair<XExpression, Map<String, Object>>> safeGet(
		Map<Pair<EObject, EStructuralFeature>, List<Pair<XExpression, Map<String, Object>>>> map,
		Pair<EObject, EStructuralFeature> p) {
		if (map.containsKey(p)) {
			return map.get(p)
		} else {
			val result = new ArrayList<Pair<XExpression, Map<String, Object>>>
			map.put(p, result)
			result
		}
	}

	override getId() {
		EMF_TRACING_PROVIDER_ID
	}

	override getRootNode() {
		return new TraceTreeNode(null, modelChanges)
	}

	override reset() {
		modelChanges.clear
	}

	override skip(String output) {
		return
	}

}
