package org.nanosite.xtendency.tracer.core

import java.lang.Exception

class RichStringException extends Exception {
	Throwable target
	new(Throwable e){
		target = e
	}
	
	def getTarget(){
		target
	}
}