package org.nanosite.xtendency.tracer.core;

import org.eclipse.xtext.xbase.XExpression;
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext;
import org.eclipse.xtext.xbase.interpreter.IEvaluationResult;
import org.nanosite.xtendency.tracer.core.TracingInterpreter;

public class SynchronizedInterpreterAccess {

	public static IEvaluationResult evaluate(
			TracingInterpreter interpreter,
			XExpression input,
			IEvaluationContext context
	) {
		synchronized (interpreter) {
			interpreter.reset();
			IEvaluationResult interpResult = interpreter.evaluate(input, context, null);
			return interpResult;
		}
	}
}
