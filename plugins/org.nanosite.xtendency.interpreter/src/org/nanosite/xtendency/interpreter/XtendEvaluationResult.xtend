package org.nanosite.xtendency.interpreter

import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationResult

class XtendEvaluationResult extends DefaultEvaluationResult {
	
	private String stackTrace
	
	new(Object result, Throwable throwable, String stackTrace) {
		super(result, throwable)
		this.stackTrace = stackTrace
	}
	
	def getStackTrace(){
		stackTrace
	}
	
}