package org.nanosite.xtendency.tracer.core

import org.eclipse.xtend.core.richstring.IRichStringPartAcceptor

interface IRichStringExecutor extends IRichStringPartAcceptor {
	
	def String getResult()
}