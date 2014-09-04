/*
 * generated by Xtext
 */
package org.nanosite.xtendency.tracer.validation

import org.eclipse.xtext.validation.Check
import org.nanosite.xtendency.tracer.runConf.RunConfiguration
import org.nanosite.xtendency.tracer.runConf.RunConfPackage

//import org.eclipse.xtext.validation.Check

/**
 * Custom validation rules. 
 *
 * see http://www.eclipse.org/Xtext/documentation.html#validation
 */
class RunConfValidator extends AbstractRunConfValidator {

	@Check
	def checkAllParametersDefines(RunConfiguration rc){
		if (rc.function != null){
			val params = rc.function.parameters.map[it.name]
			val args = rc.inits.map[it.param]
			for (p : params){
				if (!args.contains(p)){
					error("Parameter " + p + " must be initialized.", RunConfPackage.Literals.RUN_CONFIGURATION__FUNCTION)
				}
			}
			for (a : args){
				if (!params.contains(a)){
					warning("Function " + rc.function.name + " does not have a parameter named " + a + ".", RunConfPackage.Literals.RUN_CONFIGURATION__INITS, args.indexOf(a))
				}
			}
		}
	}
}
