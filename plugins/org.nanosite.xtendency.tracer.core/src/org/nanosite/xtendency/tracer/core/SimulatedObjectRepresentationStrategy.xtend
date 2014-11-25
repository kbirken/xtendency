package org.nanosite.xtendency.tracer.core

import java.util.HashMap
import java.util.List
import java.util.Map
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendField
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtext.common.types.JvmField
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.common.types.JvmConstructor
import org.eclipse.xtext.common.types.util.JavaReflectAccess

class SimulatedObjectRepresentationStrategy extends JavaObjectRepresentationStrategy implements IObjectRepresentationStrategy {
	
	private Map<Pair<Object, XtendFunction>, Map<List<?>, Object>> createCaches = new HashMap
	private Map<String, Object> staticVariables = new HashMap
	
	override protected getCreateCache(Object receiver, XtendFunction func) {
		if (receiver instanceof XtendObject){
			createCaches.get(receiver -> func)
		}else{
			super.getCreateCache(receiver, func)
		}
	}
	
	override executeConstructorCall(JvmConstructor constr, List<?> arguments) {
		super.executeConstructorCall(constr, arguments)
	}
	
	override getFieldValue(Object object, String fieldName) {
		if (object instanceof XtendObject){
			object.get(fieldName)
		}else{
			super.getFieldValue(object, fieldName)
		}
	}
	
	override getStaticFieldValue(JvmField jvmField) {
		val fqn = jvmField.qualifiedName
		if (staticVariables.containsKey(fqn)){
			return staticVariables.get(fqn)
		}else{
			super.getStaticFieldValue(jvmField)
		}
	}
	
	override setFieldValue(Object object, String fieldName, Object value) {
		if (object instanceof XtendObject){
			object.set(fieldName, value)
		}else{
			super.setFieldValue(object, fieldName, value)
		}
	}
	
	override setStaticFieldValue(JvmField jvmField, Object value) {
		val fqn = jvmField.qualifiedName
		if (staticVariables.containsKey(fqn)){
			staticVariables.put(fqn, value)
		}else{
			super.setStaticFieldValue(jvmField, value)
		}
	}
	
	override translateToJavaObject(Object inputObject) {
		if (inputObject instanceof XtendObject){
			throw new IllegalArgumentException("Native Xtend object cannot be converted to a Java object.")
		}else{
			super.translateToJavaObject(inputObject)
		}
	}
	
	override initializeClass(XtendClass clazz) {
		val fqnPrefix = (clazz.eContainer as XtendFile).package + "." + clazz.name + "."
		for (f : clazz.members.filter(XtendField)){
			var Object value = null
			if (f.initialValue != null){
				value = interpreter.internalEvaluate(f.initialValue, new ChattyEvaluationContext, CancelIndicator.NullImpl)
			}
			staticVariables.put(fqnPrefix + f.name, value)
		}
	}
	
	override init(JavaReflectAccess reflectAccess, XtendInterpreter interpreter) {
		super.init(reflectAccess, interpreter)
		createCaches.clear
		staticVariables.clear
	}
	
	override getQualifiedClassName(Object object) {
		if (object instanceof XtendObject){
			object.qualifiedClassName
		}else{
			super.getQualifiedClassName(object)
		}
	}
	
	override getSimpleClassName(Object object) {
		if (object instanceof XtendObject){
			object.simpleClassName
		}else{
			super.getSimpleClassName(object)
		}
	}
	
}