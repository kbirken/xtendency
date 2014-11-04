package org.nanosite.xtendency.tracer.core

import java.util.HashMap
import java.util.Set
import org.eclipse.xtend.core.xtend.RichStringLiteral
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.interpreter.IExpressionInterpreter
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationResult

class TracingRichStringExecutor extends DefaultRichStringExecutor {

	val Set<ITracingProvider<?>> tracingProviders

	new(IExpressionInterpreter interpreter, IEvaluationContext context, CancelIndicator indicator,
		Set<ITracingProvider<?>> tracingProviders) {
		super(interpreter, context, indicator)
		this.tracingProviders = tracingProviders
	}

	override void append(String str) {
		tracingProviders.forEach[skip(str)]
		super.append(str)
	}

	override void append(XExpression input) {
		val ctx = new HashMap<String, Object>

		tracingProviders.filter[canCreateTracePointFor(input)].forEach[enter(input, contextStack.peek)]
		val result = eval(input)
		val str = if(result == null) "NULL" else result.toString

		for (tp : tracingProviders) {

			if (tp.canCreateTracePointFor(input)) {
				tp.exit(input, contextStack.peek, str.toString)
			}
		}
		super.append(str)
	}

	override void append(RichStringLiteral lit, String str) {
		super.append(lit, str)

		for (tp : tracingProviders) {
			if (tp.canCreateTracePointFor(lit)) {
				tp.enter(lit, contextStack.peek)
				tp.exit(lit, contextStack.peek, str)
			}
		}
	}

	override protected eval(XExpression expression) {
		val result = (interpreter as TracingInterpreter).doEvaluate(expression, contextStack.peek, indicator, false)
		result
	}
}
