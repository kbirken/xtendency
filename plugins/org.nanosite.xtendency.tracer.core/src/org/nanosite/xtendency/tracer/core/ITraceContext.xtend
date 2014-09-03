package org.nanosite.xtendency.tracer.core

interface ITraceContext {
	def int enter()
	def void exit(int previousOffset)
}