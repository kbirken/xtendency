package org.nanosite.xtendency.interpreter

import javassist.util.proxy.ProxyFactory

class AllClassesProxyFactory extends ProxyFactory {
	
	new(String desiredClassName){
		ProxyFactory.nameGenerator = new UniqueName(){
			
			override get(String classname) {
				return desiredClassName
			}
			
		}
	}
	
	override protected getClassLoader0() {
		val parent = super.getClassLoader0()
		val delegator = new DelegatorClassLoader(parent)
		delegator
	}
	
}