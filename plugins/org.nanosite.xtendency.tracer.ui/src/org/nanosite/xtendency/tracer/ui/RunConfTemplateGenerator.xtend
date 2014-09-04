package org.nanosite.xtendency.tracer.ui

import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.core.resources.IFile
import org.eclipse.xtend.core.xtend.XtendFile

class RunConfTemplateGenerator {
	def static generateTemplate(XtendFunction func, IFile classFile)'''
	runConfiguration «func.name»Config {
		project "«classFile.project.name»"
		class «(func.declaringType.eContainer as XtendFile).package».«func.declaringType.name» : «func.name»
		«IF !func.parameters.empty»
		initialize {
			«FOR p : func.parameters»
			"«p.name»" = {
				return null
			}
			«ENDFOR»
		}
		«ENDIF»
	}
	'''
}