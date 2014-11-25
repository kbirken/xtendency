package org.nanosite.xtendency.tracer.core;

import java.util.List;

import org.eclipse.xtend.core.xtend.XtendFunction;
import org.eclipse.xtext.xbase.XExpression;
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext;
import org.eclipse.xtext.xbase.interpreter.IEvaluationResult;
import org.nanosite.xtendency.tracer.core.TracingInterpreter;

public class SynchronizedInterpreterAccess {

	public static IEvaluationResult evaluate(
			TracingInterpreter interpreter,
			XtendFunction input,
			Object instance,
			IClassManager classManager,
			List<Object> arguments
	) {
		synchronized (interpreter) {
			interpreter.reset();
			IEvaluationResult interpResult = interpreter.evaluateMethod(input, instance, classManager, arguments);
			return interpResult;
		}
	}
}
