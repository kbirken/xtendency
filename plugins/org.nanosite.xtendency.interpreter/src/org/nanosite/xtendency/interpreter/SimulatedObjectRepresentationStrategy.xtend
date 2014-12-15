package org.nanosite.xtendency.interpreter

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
import org.eclipse.xtext.common.types.access.impl.ClassFinder
import javassist.util.proxy.ProxyFactory
import org.eclipse.xtext.common.types.JvmDeclaredType
import java.util.Set
import java.util.ArrayList
import javassist.util.proxy.MethodHandler
import java.lang.reflect.Method
import javassist.util.proxy.Proxy
import java.util.HashSet
import org.eclipse.xtext.common.types.JvmType
import org.eclipse.xtend.core.xtend.XtendConstructor
import org.eclipse.xtext.xbase.XBlockExpression
import org.eclipse.xtext.xbase.XConstructorCall
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.common.types.util.TypeReferences
import org.eclipse.xtext.xbase.XFeatureCall
import org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtend.core.xtend.AnonymousClass
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration

class SimulatedObjectRepresentationStrategy extends JavaObjectRepresentationStrategy implements IObjectRepresentationStrategy {

	protected Map<Pair<Object, XtendFunction>, Map<List<?>, Object>> createCaches = new HashMap
	protected Map<String, Object> staticVariables = new HashMap

	override protected getCreateCache(Object receiver, XtendFunction func) {
		if (receiver instanceof IXtendObject) {
			createCaches.get(receiver -> func)
		} else {
			super.getCreateCache(receiver, func)
		}
	}

	override executeConstructorCall(XConstructorCall call, JvmConstructor constr, List<?> arguments) {
		try {
			return super.executeConstructorCall(call, constr, arguments)
		} catch (NoSuchMethodException e) {
			val newType = classManager.getClassForName(call.constructor.declaringType.qualifiedName)
			val oldType = interpreter.getCurrentType
			interpreter.setCurrentType = newType
			val Set<Class<?>> interfaces = new HashSet<Class<?>>
			interfaces += IXtendObject
			val result = executeConstructorCall(constr, arguments, interfaces)
			if (result instanceof Proxy) {
				val officialType = call.constructor.declaringType.qualifiedName
				val objectId = result.toString.split("@").tail

				val methodHandler = new MethodHandler() {

					override invoke(Object slf, Method calledMethod, Method actualMethod, Object[] args) throws Throwable {
						if (calledMethod.qualifiedName ==
							"org.nanosite.xtendency.interpreter.IXtendObject._getQualifiedClassName") {
							return officialType
						} else if (calledMethod.name == "_toString" && args.length == 0) {
							return officialType + "@" + objectId
						} else if (calledMethod.declaringClass.canonicalName == "java.lang.Object" &&
							calledMethod.name == "toString" && args.length == 0) {

							// wow this is so dirty
							val toStringMethod = IXtendObject.getDeclaredMethod("_toString")
							interpreter.invokeOperation(constr, calledMethod, slf, args, toStringMethod)
						} else {
							val callingClassName = Thread.currentThread.stackTrace.head.className
							val callingClass = classFinder.forName(callingClassName)
							if (XbaseInterpreter.isAssignableFrom(callingClass) ||
								SimulatedObjectRepresentationStrategy.isAssignableFrom(callingClass)) {
								actualMethod.invoke(slf, args)
							} else {
								interpreter.invokeOperation(constr, calledMethod, slf, args, actualMethod)
							}
						}
					}
				}
				result.handler = methodHandler
			}

			interpreter.currentType = oldType
			result
		}
	}

	override getFieldValue(Object object, JvmField jvmField) {
		if (object instanceof IXtendObject && nonCompiledClasses.contains(jvmField.declaringType.qualifiedName)) {
			memberStates.get(object).get(jvmField.qualifiedName)
		} else {
			super.getFieldValue(object, jvmField)
		}
	}

	override getStaticFieldValue(JvmField jvmField) {
		val fqn = jvmField.qualifiedName
		if (staticVariables.containsKey(fqn)) {
			return staticVariables.get(fqn)
		} else {
			super.getStaticFieldValue(jvmField)
		}
	}

	override setFieldValue(Object object, JvmField jvmField, Object value) {
		if (object instanceof IXtendObject && nonCompiledClasses.contains(jvmField.declaringType.qualifiedName)) {
			memberStates.get(object).put(jvmField.qualifiedName, value)
		} else {
			super.setFieldValue(object, jvmField, value)
		}
	}

	override setStaticFieldValue(JvmField jvmField, Object value) {
		val fqn = jvmField.qualifiedName
		if (staticVariables.containsKey(fqn)) {
			staticVariables.put(fqn, value)
		} else {
			super.setStaticFieldValue(jvmField, value)
		}
	}

	override initializeClass(XtendTypeDeclaration clazz) {
		val fqnPrefix = clazz.qualifiedClassName + "."
		for (f : clazz.members.filter(XtendField).filter[static]) {
			if (staticVariables.containsKey(fqnPrefix + f.name)) {

				// has already been initialized
				return
			}
			var Object value = null
			if (f.initialValue != null) {
				value = interpreter.internalEvaluate(f.initialValue, new ChattyEvaluationContext,
					CancelIndicator.NullImpl)
			}
			staticVariables.put(fqnPrefix + f.name, value)
		}

	}

	override init(JavaReflectAccess reflectAccess, ClassFinder classFinder, IClassManager classManager,
		TypeReferences jvmTypes, XtendInterpreter interpreter) {
		super.init(reflectAccess, classFinder, classManager, jvmTypes, interpreter)
		createCaches.clear
		staticVariables.clear
	}

	override getQualifiedClassName(Object object) {
		if (object instanceof IXtendObject) {
			object._getQualifiedClassName
		} else {
			super.getQualifiedClassName(object)
		}
	}

	override getSimpleClassName(Object object) {
		if (object instanceof IXtendObject) {
			val fqn = object._getQualifiedClassName
			return fqn.split(".").last
		} else {
			super.getSimpleClassName(object)
		}
	}

	override isInstanceOf(Object obj, String typeFQN) {
		if (obj instanceof IXtendObject) {
			if (obj._getQualifiedClassName == typeFQN) {
				return true
			} else {
				val xtendClass = classManager.getClassForName(obj._getQualifiedClassName)
				var jvmClass = jvmTypes.findDeclaredType(obj._getQualifiedClassName, xtendClass) as JvmDeclaredType
				while (jvmClass != null) {
					if (jvmClass.qualifiedName == typeFQN)
						return true
					if (jvmClass.extendedInterfaces.map[qualifiedName].exists[it == typeFQN])
						return true
					jvmClass = jvmClass.extendedClass.type as JvmDeclaredType
				}

				return false
			}
		} else {
			try {
				super.isInstanceOf(obj, typeFQN)
			} catch (Exception e) {

				// if it cant find the class it doesnt exist
				// or exists only in xtend
				// since this is not an IXtendObject, 
				// it's not an instance of the class
				return false
			}
		}
	}

}
