package org.nanosite.xtendency.tracer.core

import com.google.inject.Inject
import java.lang.reflect.InvocationTargetException
import java.util.List
import java.util.Map
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendField
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtext.common.types.JvmConstructor
import org.eclipse.xtext.common.types.JvmField
import org.eclipse.xtext.common.types.util.JavaReflectAccess
import org.eclipse.xtext.xbase.interpreter.impl.EvaluationException

class JavaObjectRepresentationStrategy implements IObjectRepresentationStrategy {

	protected JavaReflectAccess javaReflectAccess
	protected XtendInterpreter interpreter
	
	@Inject
	protected IClassManager classManager
	
	override getFieldValue(Object object, String fieldName) {
		val field = object.class.getDeclaredField(fieldName)
		field.accessible = true
		
		field.get(object)
	}
	
	override setFieldValue(Object object, String fieldName, Object value) {
		val field = object.class.getDeclaredField(fieldName)
		field.accessible = true

		field.set(object, value)
	}
	
	override setCreateMethodResult(Object object, XtendFunction method, List<?> arguments, Object result) {
		getCreateCache(object, method).put(arguments, result)
	}
	
	override hasCreateMethodResult(Object object, XtendFunction method, List<?> arguments) {
		getCreateCache(object, method).containsKey(arguments)
	}
	
	override getCreateMethodResult(Object object, XtendFunction method, List<?> arguments) {
		getCreateCache(object, method).get(arguments)
	}
	
	override translateToJavaObject(Object inputObject) {
		inputObject
	}
	
	override setStaticFieldValue(JvmField jvmField, Object value) {
		val field = javaReflectAccess.getField(jvmField)
		field.accessible = true
		field.set(null, value)
	}
	
	override getStaticFieldValue(JvmField jvmField) {
		val field = javaReflectAccess.getField(jvmField)
		field.accessible = true
		field.get(null)
	}
	
	protected def getCreateCache(Object receiver, XtendFunction func){
		var index = 0
		var methodIndex = 0
		
		val clazz = func.declaringType
		val methods = clazz.members.filter(XtendFunction).filter[f | f.name == func.name && f.createExtensionInfo != null]
		
		var foundFittingName = false		
		
		while(!foundFittingName){
			val currentName = func.getFieldName(index)
			if (clazz.members.filter(XtendField).exists[name == currentName]){
				index++
			}else{
				if (methods.get(methodIndex) == func){
					foundFittingName = true
				}else{
					methodIndex++
					index++
				}
			}
		}
		val fieldName = func.getFieldName(index)
		val field = receiver.class.getDeclaredField(fieldName)
		field.accessible = true
		field.get(receiver) as Map<List<?>, Object>
	}
	
	protected def getFieldName(XtendFunction func, int index){
		val result = "_createCache_" + func.name
		if (index > 0)
			return result + "_" + index
		else
			return result
	}
	
	override executeConstructorCall(JvmConstructor constr, List<?> arguments) {
		val constructor = javaReflectAccess.getConstructor(constr);
		try {
			if (constructor == null)
				throw new NoSuchMethodException("Could not find constructor " + constr.getIdentifier());
			constructor.setAccessible(true);
			val result = constructor.newInstance(arguments.toArray);
			return result;
		} catch (InvocationTargetException targetException) {
			throw new EvaluationException(targetException.getTargetException());
		} catch (Exception e) {
			e.printStackTrace
			throw new IllegalStateException("Could not invoke constructor: " + constr.getIdentifier(), e);
		}
	}
	
	override initializeClass(XtendClass clazz) {
		//do nothing
	}
	
	override init(JavaReflectAccess reflectAccess, XtendInterpreter interpreter) {
		this.javaReflectAccess = reflectAccess
		this.interpreter = interpreter
	}
	
	override getQualifiedClassName(Object object) {
		object.class.canonicalName
	}
	
	override getSimpleClassName(Object object) {
		object.class.simpleName
	}
	
}