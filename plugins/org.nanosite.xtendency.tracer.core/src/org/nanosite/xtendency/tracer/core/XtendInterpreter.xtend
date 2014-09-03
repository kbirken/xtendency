package org.nanosite.xtendency.tracer.core

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.List
import org.eclipse.xtend.core.richstring.DefaultIndentationHandler
import org.eclipse.xtend.core.richstring.RichStringProcessor
import org.eclipse.xtend.core.xtend.RichString
import org.eclipse.xtend.core.xtend.RichStringForLoop
import org.eclipse.xtend.core.xtend.RichStringIf
import org.eclipse.xtend.core.xtend.RichStringLiteral
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter
import org.eclipse.xtend.core.richstring.IRichStringPartAcceptor
import org.eclipse.xtext.xbase.interpreter.IExpressionInterpreter

class XtendInterpreter extends XbaseInterpreter {
	
	@Inject
	protected RichStringProcessor richStringProcessor

	@Inject	
	protected Provider<DefaultIndentationHandler> indentationHandler
	

	XtendTypeDeclaration currentType
	
	def setCurrentType(XtendTypeDeclaration thisType){
		this.currentType = thisType
	}
	

	protected def Object _doEvaluate(RichString rs, IEvaluationContext context, CancelIndicator indicator) {
		val helper = createRichStringExecutor(context, indicator)
		richStringProcessor.process(rs, helper, indentationHandler.get)
		helper.result
	}
	
	protected def IRichStringExecutor createRichStringExecutor(IEvaluationContext context, CancelIndicator indicator) {
		new DefaultRichStringExecutor(this, context, indicator)
	}
	
	
	protected override Object doEvaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator) {
		if (expression instanceof RichString){
			_doEvaluate(expression as RichString, context, indicator)
		}else{
			super.doEvaluate(expression, context, indicator)
		}
	}
	
	protected override Object invokeOperation(JvmOperation operation, Object receiver, List<Object> argumentValues,
			IEvaluationContext context, CancelIndicator indicator) {
		val calledType = operation.declaringType.qualifiedName
		if (currentType != null){
			val currentTypeName = (currentType.eContainer as XtendFile).package + "." + currentType.name
			if (currentTypeName == calledType && receiver == null){
				val calledFunc = currentType.members.findFirst[it instanceof XtendFunction && (it as XtendFunction).name == operation.simpleName && (it as XtendFunction).parameters.size == argumentValues.size] as XtendFunction
				val newContext = context.fork
				for (var i = 0; i < argumentValues.size; i++){
					val paramName = calledFunc.parameters.get(i).name
					newContext.newValue(QualifiedName.create(paramName), argumentValues.get(i))
				}
				return doEvaluate(calledFunc.expression, newContext, indicator)
			}
 		}
		super.invokeOperation(operation, receiver, argumentValues, context, indicator)
	}
	
	/*
	 * TODO: this actually inserts a string inside another, so it might break the whole offset-length counting system
	 */
//	def protected appendImmediate(StringBuilder sb, String s){
//		val str = sb.toString
//		var start = 0
//		var found = false
//		for (var i = str.length - 1; i >= 0 && !found; i--){
//			if (!Character.isWhitespace(str.charAt(i))){
//				start = i + 1
//				found = true
//			}
//		}
//		val deleted = str.substring(start, sb.length)
//		sb.delete(start, sb.length)
//		sb.append(s)
//		sb.append(deleted)		
//	}
}