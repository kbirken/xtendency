package org.nanosite.xtendency.interpreter.ors.java

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
import org.eclipse.xtext.common.types.access.impl.ClassFinder
import org.eclipse.xtext.common.types.util.TypeReferences
import org.eclipse.xtext.xbase.XConstructorCall
import org.eclipse.xtend.core.xtend.AnonymousClass
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.common.types.JvmOperation
import javassist.util.proxy.MethodHandler
import java.lang.reflect.Method
import org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter
import java.util.HashMap
import javassist.util.proxy.Proxy
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XFeatureCall
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.common.types.JvmDeclaredType
import org.eclipse.xtext.xbase.XBlockExpression
import org.eclipse.xtend.core.xtend.XtendConstructor
import java.util.Set
import java.util.HashSet
import org.eclipse.xtext.common.types.JvmGenericType
import java.lang.reflect.Constructor
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import java.util.IdentityHashMap
import org.eclipse.xtext.common.types.JvmType
import org.nanosite.xtendency.interpreter.IObjectRepresentationStrategy
import org.nanosite.xtendency.interpreter.IInterpreterAccess
import org.nanosite.xtendency.interpreter.IClassManager

class CompiledJavaObjectRepresentationStrategy implements IObjectRepresentationStrategy {
	protected ClassFinder classFinder
	protected JavaReflectAccess javaReflectAccess
	protected IInterpreterAccess interpreter
	protected TypeReferences jvmTypes

	protected IClassManager classManager

	override getFieldValue(Object object, JvmField jvmField) {
		val field = javaReflectAccess.getField(jvmField)
		field.accessible = true
		field.get(object)
	}

	override setFieldValue(Object object, JvmField jvmField, Object value) {
		val field = javaReflectAccess.getField(jvmField)
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

	protected def getCreateCache(Object receiver, XtendFunction func) {
		var index = 0
		var methodIndex = 0

		val clazz = func.declaringType
		val methods = clazz.members.filter(XtendFunction).filter[f|f.name == func.name && f.createExtensionInfo != null]

		var foundFittingName = false

		while (!foundFittingName) {
			val currentName = func.getFieldName(index)
			if (clazz.members.filter(XtendField).exists[name == currentName]) {
				index++
			} else {
				if (methods.get(methodIndex) == func) {
					foundFittingName = true
				} else {
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

	protected def getFieldName(XtendFunction func, int index) {
		val result = "_createCache_" + func.name
		if (index > 0)
			return result + "_" + index
		else
			return result
	}

	override executeConstructorCall(XConstructorCall call, JvmConstructor constr, List<?> arguments) {
		val constructor = javaReflectAccess.getConstructor(constr);
		try {
			if (constructor == null)
				throw new NoSuchMethodException("Could not find constructor " + constr.getIdentifier());
			constructor.setAccessible(true);
			val result = constructor.newInstance(arguments.toArray);
			return result;
		} catch (InvocationTargetException targetException) {
			throw new EvaluationException(targetException.getTargetException());
		}
	}

	override initializeClass(XtendTypeDeclaration clazz) {
		//do nothing
	}

	override init(JavaReflectAccess reflectAccess, ClassFinder classFinder, IClassManager classManager,
		TypeReferences jvmTypes, IInterpreterAccess interpreter) {
		this.javaReflectAccess = reflectAccess
		this.classFinder = classFinder
		this.interpreter = interpreter
		this.classManager = classManager
		this.jvmTypes = jvmTypes
	}

	override getQualifiedClassName(Object object) {
		object.class.canonicalName
	}

	override getSimpleClassName(Object object) {
		object.class.simpleName
	}

	override isInstanceOf(Object obj, String typeFQN) {
		var Class<?> expectedType = null
		val className = typeFQN
		try {
			expectedType = classFinder.forName(className)
		} catch (ClassNotFoundException cnfe) {
			throw new EvaluationException(new NoClassDefFoundError(className))
		}
		expectedType.isInstance(obj)
	}

	def static String getQualifiedName(Method m) {
		m.declaringClass.canonicalName + "." + m.name
	}

	override executeAnonymousClassConstructor(AnonymousClass clazz, List<?> arguments, IEvaluationContext context) {
		throw new UnsupportedOperationException("JavaObjectRepresentationStrategy does not support anonymous classes")
	}

	override fillAnonymousClassMethodContext(IEvaluationContext context, JvmOperation op, Object object) {
		throw new UnsupportedOperationException("JavaObjectRepresentationStrategy does not support anonymous classes")
	}

	override getClass(JvmType type, int arrayDims) {
		var arrayDimensions = "";
		for (i : 0 ..< arrayDims)
			arrayDimensions += "[]";
		return classFinder.forName(type.getQualifiedName() + arrayDimensions);
	}
	
	override getJavaOnlyMethod(Object instance, JvmOperation method) {
		throw new UnsupportedOperationException
	}

}
