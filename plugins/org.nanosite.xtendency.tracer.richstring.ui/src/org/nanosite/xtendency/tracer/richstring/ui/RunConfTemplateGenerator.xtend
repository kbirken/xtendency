package org.nanosite.xtendency.tracer.richstring.ui

import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.core.resources.IFile
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendField
import org.eclipse.xtext.common.types.JvmDeclaredType
import org.eclipse.xtend.core.xtend.XtendConstructor
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration

class RunConfTemplateGenerator {
	def static generateTemplate(XtendFunction func, IFile classFile)'''
	runConfiguration «func.name»Config {
		project "«classFile.project.name»"
		class «(func.declaringType.eContainer as XtendFile).package».«func.declaringType.name» : «func.name»
		«IF !(func.parameters.empty && func.static)»
		initialize {
			«FOR p : func.parameters»
			// parameter «p.name» of type «p.parameterType.simpleName»
			"«p.name»" = {
				return null
			}
			«ENDFOR»
			«IF !func.static»
			// the current instance
			"this" = {
				«IF func.declaringType.hasNoArgConstructor»
				return new «(func.declaringType.eContainer as XtendFile).package».«func.declaringType.name»()
				«ELSE»
				return null
				«ENDIF»
			}
«««			«FOR f : func.declaringType.members.filter(XtendField).filter[initialValue == null && !static]»
«««			// field «f.name» of type «f.type.simpleName»
«««			"«f.name»" = {
«««				return null
«««			}
«««			«ENDFOR»
			«ENDIF»
«««			«FOR f : func.declaringType.members.filter(XtendField).filter[initialValue == null && static]»
«««			// static field «f.name» of type «f.type.simpleName»
«««			"«f.name»" = {
«««				return null
«««			}
«««			«ENDFOR»
		}
		«ENDIF»
	}
	'''
	
	def private static hasNoArgConstructor(XtendTypeDeclaration type) {
		val constrs = type.members.filter(XtendConstructor)
		return constrs.empty || constrs.exists[parameters.size == 0]
	}
}