package org.nanosite.xtendency.interpreter

import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.common.types.JvmExecutable
import java.util.List
import org.eclipse.xtext.common.types.JvmOperation

interface IInterpreterAccess {
	def Object evaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator)
	def List<Object> evaluateArgumentExpressions(JvmExecutable executable, List<XExpression> expressions,
		IEvaluationContext context, CancelIndicator indicator)
	def Object invokeOperation(JvmOperation operation, Object receiver, List<Object> argumentValues,
		IEvaluationContext context, CancelIndicator indicator)
}