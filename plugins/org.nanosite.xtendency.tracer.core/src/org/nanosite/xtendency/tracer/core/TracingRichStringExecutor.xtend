package org.nanosite.xtendency.tracer.core

import org.eclipse.xtext.xbase.interpreter.IExpressionInterpreter
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.XExpression
import java.util.HashMap

class TracingRichStringExecutor extends DefaultRichStringExecutor {

	val XtendTraceContext tc
	
	new (XtendTraceContext tc, IExpressionInterpreter interpreter, IEvaluationContext context, CancelIndicator indicator) {
		super(interpreter, context, indicator)
		this.tc = tc
	}

	override void append(CharSequence str, XExpression input) {
		super.append(str, input)
		if (str.length!=0) {
			if (input==null) {
				tc.skip(str.toString)
			} else {
				val offsetBegin = tc.enter
				val ctx = new HashMap<String, Object>
				tc.setInput(input, ctx)
				tc.setOutput(offsetBegin, str.toString)
				tc.exit(offsetBegin)
			}
		}
	}
}