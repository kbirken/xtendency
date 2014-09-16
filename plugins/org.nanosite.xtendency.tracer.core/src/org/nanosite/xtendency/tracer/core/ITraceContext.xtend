package org.nanosite.xtendency.tracer.core

import org.eclipse.xtext.xbase.XExpression
import java.util.Map

interface ITraceContext324 {
	def void enter()
	def void exit()
	def void setInput(XExpression input, Map<String, Object> ctx)
	def void setOutput(Object output)
}