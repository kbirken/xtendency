package org.nanosite.xtendency.interpreter

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

class JavaObjectRepresentationStrategy implements IObjectRepresentationStrategy {
	protected ClassFinder classFinder
	protected JavaReflectAccess javaReflectAccess
	protected XtendInterpreter interpreter
	protected TypeReferences jvmTypes
	
	protected IClassManager classManager
	protected Map<Object, IEvaluationContext> anonymousClassContexts = new HashMap
	
	
	protected Map<IXtendObject, Map<String, Object>> memberStates = new HashMap

	protected Set<String> nonCompiledClasses = new HashSet
	
	
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
	
	override init(JavaReflectAccess reflectAccess, ClassFinder classFinder, IClassManager classManager, TypeReferences jvmTypes, XtendInterpreter interpreter) {
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
	
	override executeAnonymousClassConstructor(AnonymousClass clazz, List<?> arguments, IEvaluationContext context) {
		val calledType = clazz.constructorCall.constructor.declaringType.superTypes.head.type as JvmGenericType
		
		val interfaces = new HashSet<Class<?>>
		interfaces += IXtendObject
		
		val dummyConstructor = clazz.constructorCall.constructor
		
		var JvmConstructor constructor = null
		//find atual constructor
		//which is the called constructor of the superclass
		//or Object() if the supertype is an interface
		if (calledType.interface){
			constructor = (jvmTypes.findDeclaredType(Object, clazz) as JvmDeclaredType).declaredConstructors.findFirst[parameters.empty]
			interfaces += classFinder.forName(calledType.qualifiedName)
		}else{
			constructor = calledType.getDeclaredConstructors.findFirst[parameters.size == dummyConstructor.parameters.size && (0..<parameters.size).forall[i | parameters.get(i).parameterType.qualifiedName == dummyConstructor.parameters.get(i).parameterType.qualifiedName]]
		}
		
		
		val object = executeConstructorCall(constructor, arguments, interfaces)
		
		val officialType = clazz.eResource.URI.toString + clazz.eResource.getURIFragment(clazz)
		
		val methodHandler = new MethodHandler() {
			
			override invoke(Object slf, Method thisMethod, Method proceed, Object[] args) throws Throwable {
				val callingClassName = Thread.currentThread.stackTrace.head.className
				val callingClass = classFinder.forName(callingClassName)
				if (thisMethod.qualifiedName ==
					"org.nanosite.xtendency.interpreter.IXtendObject._getQualifiedClassName") {
					return officialType
				} else if (XbaseInterpreter.isAssignableFrom(callingClass) ||
					SimulatedObjectRepresentationStrategy.isAssignableFrom(callingClass)) {
					proceed.invoke(slf, args)				
				}else{
					//TODO: compare more than names
					val calledFunc = clazz.members.filter(XtendFunction).findFirst[thisMethod.name == name]
					if (calledFunc != null){
						interpreter.invokeOperation(calledFunc, thisMethod, slf, args, proceed)
					}else{
						proceed.invoke(slf, args)
					}
				}
			}
			
		}
		classManager.addAnonymousClass(officialType, clazz)
		anonymousClassContexts.put(object, context)
		(object as Proxy).handler = methodHandler
		object
	}
	
	override fillAnonymousClassMethodContext(IEvaluationContext context, JvmOperation op, Object object) {
		val result = context.fork
		val callerContext = (anonymousClassContexts.get(object) as ChattyEvaluationContext).contents
		val existingValues = (context as ChattyEvaluationContext).contents.keySet
		for (name : callerContext.keySet){
			if (!existingValues.contains(name)){
				result.newValue(QualifiedName.create(name), callerContext.get(name))
			}
		}
		result
	}
	
	def static String getQualifiedName(Method m) {
		m.declaringClass.canonicalName + "." + m.name
	}
	
	def protected executeConstructorCall(JvmConstructor jvmConstr, List<?> arguments,
		Set<Class<? extends Object>> interfaces) {

		//TODO: do initialize class and initialize object on the way
		//possibly also make a record of fields belonging to classes and stuff
		val type = jvmConstr.declaringType.qualifiedName
		val context = new ChattyEvaluationContext
		if (jvmConstr.parameters.size != arguments.size)
			throw new IllegalArgumentException
		for (i : 0 ..< arguments.size)
			context.newValue(QualifiedName.create(jvmConstr.parameters.get(i).name), arguments.get(i))
		try {
			val clazz = classFinder.forName(type)
			val factory = new AllClassesProxyFactory
			factory.superclass = clazz

			factory.interfaces = interfaces

			val newClass = factory.createClass

			val constr = newClass.getDeclaredConstructor(
				jvmConstr.parameters.map[classFinder.forName(parameterType.qualifiedName)])

			val result = constr.newInstance(arguments.toArray)

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
				var XBlockExpression constructorExpression = if(xtendConstr != null &&
						xtendConstr.expression instanceof XBlockExpression) xtendConstr.expression as XBlockExpression else null
				if (constructorExpression != null && clazz.extends != null &&
					constructorExpression.expressions.head instanceof XFeatureCall &&
					(constructorExpression.expressions.head as XFeatureCall).feature instanceof JvmConstructor) {
					val newCall = constructorExpression.expressions.head as XFeatureCall
					object = executeConstructorCall(newCall.feature as JvmConstructor,
						interpreter.evaluateArgumentExpressions(newCall.feature as JvmConstructor,
							newCall.actualArguments, context, CancelIndicator.NullImpl), allInterfaces) as IXtendObject
				} else {
					var newClass = clazz.extends?.type as JvmDeclaredType
					if (newClass == null)
						newClass = jvmTypes.findDeclaredType(Object, clazz) as JvmDeclaredType
					val constr = newClass.declaredConstructors.findFirst[parameters.empty]
					if (constr == null)
						println("!!!!")
					object = executeConstructorCall(constr, #[], allInterfaces) as IXtendObject
				}

				val state = object.objectState

				//initialize member variables
				//TODO: should this be done before calling the super constructor?
				for (f : clazz.members.filter(XtendField).filter[!static]) {
					val fieldFqn = type + "." + f.name
					if (f.initialValue != null) {
						val value = interpreter.internalEvaluate(f.initialValue, new ChattyEvaluationContext,
							CancelIndicator.NullImpl)
						state.put(fieldFqn, value)
					} else {
						state.put(fieldFqn, null)
					}
				}

				// execute rest of constructor
				if (constructorExpression != null) {
					context.newValue(QualifiedName.create("this"), object)
					val first = constructorExpression.expressions.head
					var Iterable<XExpression> todo = null
					if (first instanceof XFeatureCall && (first as XFeatureCall).feature instanceof JvmConstructor)
						todo = constructorExpression.expressions.tail
					else
						todo = constructorExpression.expressions
					for (expr : todo) {
						interpreter.internalEvaluate(expr, context, CancelIndicator.NullImpl)
					}
				}

				return object
			} else {
				throw new IllegalStateException
			}
		}
	}
	
	def protected getObjectState(IXtendObject object) {
		if (memberStates.containsKey(object)) {
			memberStates.get(object)
		} else {
			val result = new HashMap<String, Object>
			memberStates.put(object, result)
			return result
		}
	}
	
}