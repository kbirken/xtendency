package org.nanosite.xtendency.tracer.core

import org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter
import org.eclipse.xtend.core.xtend.RichStringForLoop
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtend.core.xtend.RichString
import org.eclipse.xtend.core.xtend.RichStringIf
import org.eclipse.xtend.core.xtend.RichStringLiteral
import org.eclipse.xtext.naming.QualifiedName

class XtendInterpreter extends XbaseInterpreter {
	
	protected def Object _doEvaluate(RichString rs, IEvaluationContext context, CancelIndicator indicator){
		rs.evaluateRichString(context, indicator)
	}
	
	protected def String evaluateRichString(XExpression e, IEvaluationContext context, CancelIndicator indicator){
		val result = doEvaluateRichString(e, context, indicator)
		return result
	}
	
	protected def dispatch String doEvaluateRichString(RichStringLiteral s, IEvaluationContext context, CancelIndicator indicator){
		s.value
	}
	
	protected def dispatch String doEvaluateRichString(RichString s, IEvaluationContext context, CancelIndicator indicator){
		val sb = new StringBuilder
		for (e : s.expressions){
			val toAppend = e.evaluateRichString(context, indicator)
			sb.append(toAppend)
		}
		sb.toString
	}
	
	protected def dispatch String doEvaluateRichString(RichStringIf i, IEvaluationContext context, CancelIndicator indicator){
		if (i.^if.internalEvaluate(context, indicator) as Boolean){
			return i.then.evaluateRichString(context, indicator)
		}else{
			for (ei : i.elseIfs){
				if (ei.^if.internalEvaluate(context, indicator) as Boolean){
					return ei.then.evaluateRichString(context, indicator)
				}
			}
			if (i.^else != null){
				return i.^else.evaluateRichString(context, indicator)
			}else {
				return ""
			}
		}
	}
	
	protected def dispatch String doEvaluateRichString(RichStringForLoop f, IEvaluationContext context, CancelIndicator indicator){
		val sb = new StringBuilder
		if (f.before != null)
			sb.append(f.before.evaluateRichString(context, indicator))
			
		val iter = (f.forExpression.internalEvaluate(context, indicator) as Iterable<?>).iterator
		while(iter.hasNext){
			val current = iter.next
			val newContext = context.fork
			newContext.newValue(QualifiedName.create(f.declaredParam.getQualifiedName('$')), current)
			sb.append(f.eachExpression.evaluateRichString(newContext, indicator))
			if (iter.hasNext && f.separator != null){
				val sep = f.separator.evaluateRichString(context, indicator)
				sb.appendImmediate(sep)
			}
		}
			
		if (f.after != null)
			sb.append(f.after.evaluateRichString(context, indicator))
		
		sb.toString
	}
	
	protected def dispatch String doEvaluateRichString(XExpression e, IEvaluationContext context, CancelIndicator indicator){
		val o = internalEvaluate(e, context, indicator)
		o?.toString ?: "null"
	}
	
	protected override Object doEvaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator) {
		if (expression instanceof RichString){
			_doEvaluate(expression as RichString, context, indicator)
		}else{
			super.doEvaluate(expression, context, indicator)
		}
	}
	
	/*
	 * TODO: this actually inserts a string inside another, so it might break the whole offset-length counting system
	 */
	def protected appendImmediate(StringBuilder sb, String s){
		val str = sb.toString
		var start = 0
		var found = false
		for (var i = str.length - 1; i >= 0 && !found; i--){
			if (!Character.isWhitespace(str.charAt(i))){
				start = i + 1
				found = true
			}
		}
		val deleted = str.substring(start, sb.length)
		sb.delete(start, sb.length)
		sb.append(s)
		sb.append(deleted)		
	}
}