package org.nanosite.xtendency.tracer.core

import org.eclipse.xtext.xbase.interpreter.IExpressionInterpreter
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.XExpression
import java.util.HashMap
import java.util.Set
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import org.eclipse.xtend.core.xtend.RichStringLiteral

class TracingRichStringExecutor extends DefaultRichStringExecutor {

	val Set<ITracingProvider<?>> tracingProviders

	new(IExpressionInterpreter interpreter, IEvaluationContext context, CancelIndicator indicator,
		Set<ITracingProvider<?>> tracingProviders) {
		super(interpreter, context, indicator)
		this.tracingProviders = tracingProviders
	}

//	override void append(CharSequence str, XExpression input) {
//		super.append(str, input)
//		if (str.length != 0) {
//			if (input == null) {
//				tracingProviders.forEach[skip(str.toString)]
//			} else {
//				val ctx = new HashMap<String, Object>
//				for (tp : tracingProviders) {
//					if (input instanceof XAbstractFeatureCall)
//						println("!!!")
//					if (tp.canCreateTracePointFor(input)) {
//						tp.enter
//						tp.setInput(input, ctx)
//						tp.setOutput(str.toString)
//						tp.exit
//					}
//				}
//			}
//		}
//	}

	override void append(String str) {
		tracingProviders.forEach[skip(str)]
		super.append(str)
	}

	override void append(XExpression input) {
		val ctx = new HashMap<String, Object>
		
		tracingProviders.filter[canCreateTracePointFor(input)].forEach[enter]
		val str = eval(input).toString
		
		for (tp : tracingProviders) {

			if (tp.canCreateTracePointFor(input)) {
				//tp.enter
				tp.setInput(input, ctx)
				tp.setOutput(str.toString)
				tp.exit
			}
		}
		super.append(str)
	}
	
	override void append(RichStringLiteral lit, String str){
		super.append(lit, str)
		if (str == "\t")
		println("56546")
		val ctx = new HashMap<String, Object>
		
		for (tp : tracingProviders){
			if (tp.canCreateTracePointFor(lit)){
				tp.enter
				tp.setInput(lit, ctx)
				tp.setOutput(str)
				tp.exit
			}
		}
	}

	override protected eval(XExpression expression) {
		try {
			val result = (interpreter as TracingInterpreter).doEvaluate(expression, contextStack.peek, indicator, false)
			result
		} catch (Exception e) {
			e.printStackTrace
			null
		}

	//		if (result.exception!=null) {
	//			System.err.println("ERROR during evaluation: " + result.exception.toString)			
	//			null
	//		} else {
	//			result.result
	//		}
	}
}
