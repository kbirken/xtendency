package org.nanosite.xtendency.tracer.core.ui

import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.core.resources.IFile
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendField
import org.eclipse.xtext.common.types.JvmDeclaredType
import org.eclipse.xtend.core.xtend.XtendConstructor
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.core.runtime.Platform
import org.nanosite.xtendency.tracer.core.IGeneratedView
import org.eclipse.xtext.common.types.JvmTypeReference
import com.google.inject.Inject
import org.eclipse.xtext.xbase.jvmmodel.JvmTypesBuilder

class ExecutionContextTemplateGenerator {
	@Inject static extension JvmTypesBuilder
	
	def static generateTemplate(XtendFunction func, IFile classFile)'''
	executionContext «func.name» {
		project "«classFile.project.name»"
		class «(func.declaringType.eContainer as XtendFile).package».«func.declaringType.name» : «func.functionName»
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
		tracingScope package
		view "«func.getFittingView»"
	}
	'''
	
	def private static getFittingView(XtendFunction func){
		val views = Platform.getExtensionRegistry().getConfigurationElementsFor("org.nanosite.xtendency.tracer.view")
		//val fitting = views.findFirst[v | (v.createExecutableExtension("class") as IGeneratedView).acceptsInputClass(func?.actualType?.type?.qualifiedName)]
		val fitting = views.head
		//TODO
		fitting.getAttribute("name")
	}
	
	def static private JvmTypeReference getActualType(XtendFunction func){
		if (func.returnType != null)
			return func.returnType
		func.expression.inferredType
	}
	
	def private static hasNoArgConstructor(XtendTypeDeclaration type) {
		val constrs = type.members.filter(XtendConstructor)
		return constrs.empty || constrs.exists[parameters.size == 0]
	}
	
	def private static getFunctionName(XtendFunction f){
		val sb = new StringBuilder
		sb.append(f.name)
		sb.append("(")
		for (i : 0..<f.parameters.size){
			sb.append(f.parameters.get(i).parameterType.type.simpleName)
			if (i < f.parameters.size - 1)
				sb.append(", ")
		}
		sb.append(")")
		sb.toString
	}
}