package org.nanosite.xtendency.interpreter

import javassist.util.proxy.ProxyFactory

class AllClassesProxyFactory extends ProxyFactory {
	
	override protected getClassLoader0() {
		val parent = super.getClassLoader0()
		val delegator = new DelegatorClassLoader(parent)
		delegator
	}
	
}