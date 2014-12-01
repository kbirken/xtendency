package org.nanosite.xtendency.tracer.emf

import java.util.ArrayList
import java.util.HashMap
import java.util.List
import java.util.Map
import java.util.Set
import java.util.Stack
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtext.xbase.XAssignment
import org.eclipse.xtext.xbase.XBinaryOperation
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XMemberFeatureCall
import org.eclipse.xtext.xbase.XbasePackage
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.nanosite.xtendency.interpreter.ChattyEvaluationContext
import org.nanosite.xtendency.tracer.core.ITracingProvider
import org.nanosite.xtendency.tracer.core.TraceTreeNode

class EmfTracingProvider implements ITracingProvider<Map<Pair<EObject, EStructuralFeature>, List<Pair<XExpression, Map<String, Object>>>>> {
	public static final String EMF_TRACING_PROVIDER_ID = "org.nanosite.xtendency.tracer.emf"

	private Map<Pair<EObject, EStructuralFeature>, List<Pair<Pair<XExpression, Map<String, Object>>, Object>>> modelChanges

	private Stack<Map<XExpression, Object>> lastEvaluated = new Stack<Map<XExpression, Object>>

	private Set<EClass> trackedExpressions = #{XbasePackage.Literals.XASSIGNMENT, XbasePackage.Literals.XMEMBER_FEATURE_CALL, XbasePackage.Literals.XBINARY_OPERATION}

	new() {
		modelChanges = new HashMap<Pair<EObject, EStructuralFeature>, List<Pair<Pair<XExpression, Map<String, Object>>, Object>>>
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
		if (expr instanceof XAssignment) {
			if (expr.feature instanceof JvmOperation) {
				if (!lastEvaluated.peek.containsKey(expr.assignable))
					throw new IllegalStateException
				if (!lastEvaluated.peek.containsKey(expr.value))
					throw new IllegalStateException
				val receiverObj = lastEvaluated.peek.get(expr.assignable)
				val assigned = lastEvaluated.peek.get(expr.value)
				if (receiverObj != null && receiverObj instanceof EObject){
					logChange(expr.feature as JvmOperation, receiverObj as EObject, expr, ctx, assigned)
				}
			}
		}else if (expr instanceof XMemberFeatureCall) {
			if (expr.feature instanceof JvmOperation && expr.memberCallArguments.size == 1) {
				if (!lastEvaluated.peek.containsKey(expr.memberCallTarget))
					throw new IllegalStateException
				if (!lastEvaluated.peek.containsKey(expr.memberCallArguments.head))
					throw new IllegalStateException
				val receiverObj = lastEvaluated.peek.get(expr.memberCallTarget)
				val assigned = lastEvaluated.peek.get(expr.memberCallArguments.head)
				if (receiverObj != null && receiverObj instanceof EObject){
					logChange(expr.feature as JvmOperation, receiverObj as EObject, expr, ctx, assigned)
				}
			}
			if (expr.memberCallTarget instanceof XMemberFeatureCall && expr.feature instanceof JvmOperation && expr.memberCallArguments.size == 1){
				val feat = expr.feature as JvmOperation
				val getter = expr.memberCallTarget as XMemberFeatureCall
				if (feat.simpleName.startsWith("add") && getter.feature instanceof JvmOperation && getter.memberCallArguments.empty){
					if (!lastEvaluated.peek.containsKey(getter.memberCallTarget))
						throw new IllegalStateException
					if (!lastEvaluated.peek.containsKey(expr.memberCallArguments.head))
						throw new IllegalStateException
					val receiverObj = lastEvaluated.peek.get(getter.memberCallTarget)
					val assigned = lastEvaluated.peek.get(expr.memberCallArguments.head)
					if (receiverObj != null && receiverObj instanceof EObject){
						logChange(getter.feature as JvmOperation, receiverObj as EObject, expr, ctx, assigned)
					}
				}
			}
		}else if (expr instanceof XBinaryOperation) {
			if (expr.leftOperand instanceof XMemberFeatureCall && expr.feature instanceof JvmOperation){
				val feat = expr.feature as JvmOperation
				val getter = expr.leftOperand as XMemberFeatureCall
				if (feat.simpleName == "operator_add" && getter.feature instanceof JvmOperation && getter.memberCallArguments.empty){
					if (!lastEvaluated.peek.containsKey(getter.memberCallTarget))
						throw new IllegalStateException
					if (!lastEvaluated.peek.containsKey(expr.rightOperand))
						throw new IllegalStateException
					val receiverObj = lastEvaluated.peek.get(getter.memberCallTarget)
					val assigned = lastEvaluated.peek.get(expr.rightOperand)
					if (receiverObj != null && receiverObj instanceof EObject){
						logChange(getter.feature as JvmOperation, receiverObj as EObject, expr, ctx, assigned)
					}
				}
			}
		}
		if (trackedExpressions.contains(expr.eContainer.eClass)) {
			lastEvaluated.peek.put(expr, output)
		}
		if (expr.eContainer instanceof XtendFunction)
			lastEvaluated.pop
	}

	def logChange(JvmOperation op, EObject receiverObj, XExpression expr, IEvaluationContext ctx, Object assignedValue) {
		if (op.simpleName.startsWith("set") || op.simpleName.startsWith("get")) {
			val sfName = op.simpleName.substring(3)
			var sf = receiverObj.eClass.EAllStructuralFeatures.findFirst[name == sfName || name == sfName.toFirstLower]
			if (sf != null) {
				val ctxMap = if (ctx instanceof ChattyEvaluationContext) ctx.contents else new HashMap<String, Object>
				modelChanges.safeGet(receiverObj -> sf).add((expr -> ctxMap) -> assignedValue)
			}
		}
	}

	def List<Pair<Pair<XExpression, Map<String, Object>>, Object>> safeGet(
		Map<Pair<EObject, EStructuralFeature>, List<Pair<Pair<XExpression, Map<String, Object>>, Object>>> map,
		Pair<EObject, EStructuralFeature> p) {
		if (map.containsKey(p)) {
			return map.get(p)
		} else {
			val result = new ArrayList<Pair<Pair<XExpression, Map<String, Object>>, Object>>
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
