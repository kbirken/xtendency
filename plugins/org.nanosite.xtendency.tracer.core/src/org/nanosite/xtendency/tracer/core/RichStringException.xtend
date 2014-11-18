package org.nanosite.xtendency.tracer.core

import java.lang.Exception
import org.eclipse.xtext.xbase.XExpression
import java.util.Stack

class RichStringException extends Exception {
	Throwable target
	new(Throwable e){
		target = e
	}
	
	def getTarget(){
		target
	}
}