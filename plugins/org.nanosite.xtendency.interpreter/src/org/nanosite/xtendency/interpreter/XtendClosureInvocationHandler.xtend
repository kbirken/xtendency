package org.nanosite.xtendency.interpreter

import org.eclipse.xtext.xbase.interpreter.impl.ClosureInvocationHandler
import org.eclipse.xtext.xbase.XClosure
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.interpreter.IExpressionInterpreter
import org.eclipse.xtext.util.CancelIndicator
import java.lang.reflect.Method
import org.eclipse.xtext.xbase.interpreter.impl.InterpreterCanceledException

class XtendClosureInvocationHandler extends ClosureInvocationHandler {
	
	protected IEvaluationContext context
	protected XClosure closure
	protected XtendInterpreter interpreter
	protected CancelIndicator indicator
	
	new(XClosure closure, IEvaluationContext context, IExpressionInterpreter interpreter, CancelIndicator indicator) {
		super(closure, context, interpreter, indicator)
		this.context = context
		this.closure = closure
		this.indicator = indicator
		if (interpreter instanceof XtendInterpreter)
			this.interpreter = interpreter
		else
			throw new IllegalArgumentException
	}
	
	override Object doInvoke(Method method, Object[] args) throws Throwable {
		val forkedContext = context.fork();
		if (args != null) {
			initializeClosureParameters(forkedContext, args);
		}
		val result = interpreter.internalEvaluate(closure.getExpression(), forkedContext, indicator);
		if (indicator.isCanceled())
			throw new InterpreterCanceledException();
		return result;
	}
	
}