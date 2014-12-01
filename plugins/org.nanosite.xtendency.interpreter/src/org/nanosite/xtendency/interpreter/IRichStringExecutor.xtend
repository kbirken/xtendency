package org.nanosite.xtendency.interpreter

import org.eclipse.xtend.core.richstring.IRichStringPartAcceptor

interface IRichStringExecutor extends IRichStringPartAcceptor {
	
	def String getResult()
}