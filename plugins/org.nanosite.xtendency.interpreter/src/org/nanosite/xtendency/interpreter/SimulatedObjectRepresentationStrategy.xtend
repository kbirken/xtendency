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

class SimulatedObjectRepresentationStrategy extends JavaObjectRepresentationStrategy implements IObjectRepresentationStrategy {

	protected Map<Pair<Object, XtendFunction>, Map<List<?>, Object>> createCaches = new HashMap
	protected Map<String, Object> staticVariables = new HashMap
	protected Map<IXtendObject, Map<String, Object>> memberStates = new HashMap
	
	protected Set<String> nonCompiledClasses = new HashSet

	override protected getCreateCache(Object receiver, XtendFunction func) {
		if (receiver instanceof IXtendObject) {
			createCaches.get(receiver -> func)
		} else {
			super.getCreateCache(receiver, func)
		}
	}

	def static String getQualifiedName(Method m) {
		m.declaringClass.canonicalName + "." + m.name
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
			val result =  executeConstructorCall(call, constr, arguments, interfaces)
			interpreter.currentType = oldType
			result
		}
	}

	def protected executeConstructorCall(XConstructorCall call, JvmConstructor jvmConstr, List<?> arguments, Set<Class<? extends Object>> interfaces) {
		//TODO: do initialize class and initialize object on the way
		//possibly also make a record of fields belonging to classes and stuff
		val type = jvmConstr.declaringType.qualifiedName
		val context = new ChattyEvaluationContext
		if (jvmConstr.parameters.size != arguments.size)
			throw new IllegalArgumentException
		for (i : 0..<arguments.size)
			context.newValue(QualifiedName.create(jvmConstr.parameters.get(i).name), arguments.get(i))
		try {
			val clazz = classFinder.forName(type)
			val factory = new AllClassesProxyFactory
			factory.superclass = clazz

			factory.interfaces = interfaces

			val newClass = factory.createClass

			val constr = newClass.getDeclaredConstructor(
				jvmConstr.parameters.map[classFinder.forName(parameterType.qualifiedName)])
				
			val officialType = call.constructor.declaringType.qualifiedName
			
			var Object result = null
			try{
				result = constr.newInstance(arguments.toArray)
			}catch(IllegalArgumentException e){
				e.printStackTrace
			}
			val objectId = result.toString.split("@").tail
			
			val methodHandler = new MethodHandler() {

				override invoke(Object slf, Method calledMethod, Method actualMethod, Object[] args) throws Throwable {
					if (calledMethod.qualifiedName ==
						"org.nanosite.xtendency.interpreter.IXtendObject._getQualifiedClassName") {
						return officialType
					}else if (calledMethod.name == "_toString" && args.length == 0){
						return officialType + "@" + objectId
					}else if (calledMethod.name == "toString" && args.length == 0){
						// wow this is so dirty
						val toStringMethod = IXtendObject.getDeclaredMethod("_toString")
						interpreter.invokeOperation(call, calledMethod, slf, args, toStringMethod)
					}else {
						val callingClassName = Thread.currentThread.stackTrace.head.className
						val callingClass = classFinder.forName(callingClassName)
						if (XbaseInterpreter.isAssignableFrom(callingClass) 
							|| SimulatedObjectRepresentationStrategy.isAssignableFrom(callingClass)){
							actualMethod.invoke(slf, args)
						}else{
							interpreter.invokeOperation(call, calledMethod, slf, args, actualMethod)
						}
					}
				}
			}
			
			(result as Proxy).handler = methodHandler
			return result
		} catch (ClassNotFoundException e) {
			if (classManager.canInterpretClass(type)) {
				nonCompiledClasses += type
				val clazz = classManager.getClassForName(type) as XtendClass
				clazz.initializeClass
				val newInterfaces = clazz.implements.map[classFinder.forName(qualifiedName)]
				val allInterfaces = new HashSet(interfaces)
				allInterfaces += newInterfaces
				
				// find and execute super or this constructor call
				val xtendConstr = clazz.members.filter(XtendConstructor).findFirst[
					InterpreterUtil.operationsEqual(it, jvmConstr)]
				if (xtendConstr == null && jvmConstr.parameters.size != 0)
					throw new IllegalArgumentException
				
				// get actual object
				var IXtendObject object = null
				var XBlockExpression constructorExpression = if (xtendConstr != null && xtendConstr.expression instanceof XBlockExpression) xtendConstr.expression as XBlockExpression else null
				if (constructorExpression != null && clazz.extends != null &&
					constructorExpression.expressions.head instanceof XFeatureCall && (constructorExpression.expressions.head as XFeatureCall).feature instanceof JvmConstructor) {
					val newCall = constructorExpression.expressions.head as XFeatureCall
					object = executeConstructorCall(call, newCall.feature as JvmConstructor, interpreter.evaluateArgumentExpressions(newCall.feature as JvmConstructor, newCall.actualArguments, context, CancelIndicator.NullImpl), allInterfaces) as IXtendObject
				} else {
					var newClass = clazz.extends?.type as JvmDeclaredType
					if (newClass == null) 
						newClass = jvmTypes.findDeclaredType(Object, clazz) as JvmDeclaredType
					val constr = newClass.declaredConstructors.findFirst[parameters.empty]
					if (constr == null)
						println("!!!!")
					object = executeConstructorCall(call, constr, #[], allInterfaces) as IXtendObject
				}
				
				val state = object.objectState
				//initialize member variables
				//TODO: should this be done before calling the super constructor?
				for (f : clazz.members.filter(XtendField).filter[!static]){
					val fieldFqn = type + "." + f.name
					if (f.initialValue != null){
						val value = interpreter.internalEvaluate(f.initialValue, new ChattyEvaluationContext, CancelIndicator.NullImpl)
						state.put(fieldFqn, value)
					}else{
						state.put(fieldFqn, null)
					}
				}
				
				// execute rest of constructor
				if (constructorExpression != null){
					context.newValue(QualifiedName.create("this"), object)
					val first = constructorExpression.expressions.head
					var Iterable<XExpression> todo = null
					if (first instanceof XFeatureCall && (first as XFeatureCall).feature instanceof JvmConstructor) 
						todo = constructorExpression.expressions.tail 
					else 
						todo = constructorExpression.expressions
					for (expr : todo){
						interpreter.internalEvaluate(expr, context, CancelIndicator.NullImpl)
					}
				}
				
				return object
			} else {
				throw new IllegalStateException
			}
		}
	}
	
	def protected getObjectState(IXtendObject object){
		if (memberStates.containsKey(object)){
			memberStates.get(object)
		}else{
			val result = new HashMap<String, Object>
			memberStates.put(object, result)
			return result
		}
	}

	override getFieldValue(Object object, JvmField jvmField) {
		if (object instanceof IXtendObject && nonCompiledClasses.contains(jvmField.declaringType.qualifiedName)){
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
		if (object instanceof IXtendObject && nonCompiledClasses.contains(jvmField.declaringType.qualifiedName)){
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

	override translateToJavaObject(Object inputObject) {
		return inputObject
	}

	override initializeClass(XtendClass clazz) {
		val fqnPrefix = (clazz.eContainer as XtendFile).package + "." + clazz.name + "."
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

	override init(JavaReflectAccess reflectAccess, ClassFinder classFinder, IClassManager classManager, TypeReferences jvmTypes,
		XtendInterpreter interpreter) {
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
				while (jvmClass != null){
					if (jvmClass.qualifiedName == typeFQN)
						return true
					if (jvmClass.extendedInterfaces.map[qualifiedName].exists[it == typeFQN])
						return true
					jvmClass = jvmClass.extendedClass.type as JvmDeclaredType
				}
				
				return false
			}
		} else {
			try{
				super.isInstanceOf(obj, typeFQN)
			}catch (Exception e){
				// if it cant find the class it doesnt exist
				// or exists only in xtend
				// since this is not an IXtendObject, 
				// it's not an instance of the class
				return false
			}
		}
	}

}
