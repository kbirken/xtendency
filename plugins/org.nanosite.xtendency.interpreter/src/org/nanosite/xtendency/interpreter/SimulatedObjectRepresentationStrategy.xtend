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
import org.eclipse.xtext.common.types.JvmGenericType
import java.util.IdentityHashMap
import javassist.ClassPool
import javassist.CtMethod
import javassist.CtNewMethod
import javassist.CtNewConstructor
import javassist.CtClass
import javassist.NotFoundException
import javassist.CtField
import static extension org.nanosite.xtendency.interpreter.InterpreterUtil.*
import org.eclipse.xtext.xbase.interpreter.impl.NullEvaluationContext
import java.lang.reflect.Member
import java.lang.reflect.Modifier
import javassist.LoaderClassPath
import javassist.CannotCompileException
import org.eclipse.xtext.common.types.JvmPrimitiveType
import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Array
import org.eclipse.xtext.common.types.JvmVoid
import javassist.bytecode.DuplicateMemberException

@Data class MethodSignature {
	String fqn
	String simpleName
	String returnType
	List<String> parameters
}

@Data class ConstructorSignature {
	List<String> parameters
}

class SimulatedObjectRepresentationStrategy extends JavaObjectRepresentationStrategy implements IObjectRepresentationStrategy {
	protected static final String DELEGATE_METHOD_MARKER = "__delegate_"

	protected Map<Pair<Object, XtendFunction>, Map<List<?>, Object>> createCaches = new HashMap
	protected Map<String, Object> staticVariables = new HashMap

	protected Map<Object, IEvaluationContext> anonymousClassContexts = new IdentityHashMap

	protected Set<String> nonCompiledClasses = new HashSet

	protected Map<XtendClass, CtClass> createdClasses = new HashMap
	protected Map<CtClass, Class<?>> compiledClasses = new HashMap

	protected ClassPool pool = ClassPool.getDefault

	public static Map<String, SimulatedObjectRepresentationStrategy> instances = new HashMap<String, SimulatedObjectRepresentationStrategy>

	override protected getCreateCache(Object receiver, XtendFunction func) {
		if (receiver instanceof IXtendObjectMarker) {
			createCaches.get(receiver -> func)
		} else {
			super.getCreateCache(receiver, func)
		}
	}

	override executeConstructorCall(XConstructorCall call, JvmConstructor constr, List<?> arguments) {
		try {
			return super.executeConstructorCall(call, constr, arguments)
		} catch (NoSuchMethodException e) {
			val clazz = constr.declaringType.qualifiedName.createdClass
			val constructor = clazz.constructors.findFirst[constructorsEqual(constr, it)]
			if (constructor == null)
				throw new NoSuchMethodException("Could not find constructor " + constr.getIdentifier());
			constructor.setAccessible(true);
			try {
				val result = constructor.newInstance(arguments.toArray);
				return result;
			} catch (InvocationTargetException ex) {
				ex.printStackTrace
				null
			}

		}
	}

	override getFieldValue(Object object, JvmField jvmField) {
		try {
			super.getFieldValue(object, jvmField)
		} catch (Exception e) {
			object.getFieldForSimulatedClass(jvmField.declaringType.qualifiedName, jvmField.simpleName)
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
		try {
			super.setFieldValue(object, jvmField, value)
		} catch (Exception e) {
			setFieldForSimulatedClass(object, jvmField.declaringType.qualifiedName, jvmField.simpleName, value)
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
		val fqnPrefix = InterpreterUtil.getQualifiedName(clazz) + "."
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
		instances.put(this.toString, this)
		pool.appendClassPath(new LoaderClassPath(classManager.configuredClassLoader))
	}

	override getQualifiedClassName(Object object) {

		//TODO: do something for anonymous classes, should return null
		//unless that breaks something
		object.class.canonicalName
	}

	override getSimpleClassName(Object object) {

		//TODO: do something for anonymous classes, should return null
		//unless that breaks something
		object.class.simpleName
	}

	override isInstanceOf(Object obj, String typeFQN) {
		var Class<?> clazz = null
		try {
			clazz = classFinder.forName(typeFQN)
		} catch (ClassNotFoundException e) {
			clazz = getCreatedClass(typeFQN)
		}

		clazz.isInstance(obj)
	}

	override executeAnonymousClassConstructor(AnonymousClass clazz, List<?> arguments, IEvaluationContext context) {
		val calledType = clazz.constructorCall.constructor.declaringType.superTypes.head.type as JvmGenericType

		val interfaces = new HashSet<Class<?>>

		val dummyConstructor = clazz.constructorCall.constructor

		var JvmConstructor constructor = null

		//find actual constructor
		//which is the called constructor of the superclass
		//or Object() if the supertype is an interface
		if (calledType.interface) {
			constructor = (jvmTypes.findDeclaredType(Object, clazz) as JvmDeclaredType).declaredConstructors.findFirst[
				parameters.empty]
			interfaces += classFinder.forName(calledType.qualifiedName)
		} else {
			constructor = calledType.getDeclaredConstructors.findFirst[
				parameters.size == dummyConstructor.parameters.size && (0 ..< parameters.size).forall[i|
					parameters.get(i).parameterType.qualifiedName ==
						dummyConstructor.parameters.get(i).parameterType.qualifiedName]]
		}

		val officialType = clazz.constructorCall.constructor.declaringType.identifier
		val object = null

		classManager.addAnonymousClass(officialType, clazz)
		anonymousClassContexts.put(object, context)

		object
	}

	//no longer needed
	//	def protected executeConstructorCall(JvmConstructor jvmConstr, List<?> arguments,
	//		Set<Class<? extends Object>> interfaces, (Proxy)=>MethodHandler handler, String classFqn) {
	//
	//		//TODO: do initialize class and initialize object on the way
	//		//possibly also make a record of fields belonging to classes and stuff
	//		val type = jvmConstr.declaringType.qualifiedName
	//		val context = new ChattyEvaluationContext
	//		if (jvmConstr.parameters.size != arguments.size)
	//			throw new IllegalArgumentException
	//		for (i : 0 ..< arguments.size)
	//			context.newValue(QualifiedName.create(jvmConstr.parameters.get(i).name), arguments.get(i))
	//		try {
	//			val clazz = classFinder.forName(type)
	//			val factory = new AllClassesProxyFactory(classFqn)
	//			factory.superclass = clazz
	//
	//			factory.interfaces = interfaces
	//
	//			val newClass = factory.createClass
	//
	//			val constr = newClass.getDeclaredConstructor(
	//				jvmConstr.parameters.map[classFinder.forName(parameterType.qualifiedName)])
	//
	//			val result = constr.newInstance(arguments.toArray)
	//			val methodHandler = handler.apply(result as Proxy)
	//			(result as Proxy).handler = methodHandler
	//
	//			return result
	//		} catch (ClassNotFoundException e) {
	//			if (classManager.canInterpretClass(type)) {
	//				nonCompiledClasses += type
	//				val clazz = classManager.getClassForName(type) as XtendClass
	//				clazz.initializeClass
	//				val newInterfaces = clazz.implements.map[classFinder.forName(qualifiedName)]
	//				val allInterfaces = new HashSet(interfaces)
	//				allInterfaces += newInterfaces
	//
	//				// find and execute super or this constructor call
	//				val xtendConstr = clazz.members.filter(XtendConstructor).findFirst[
	//					InterpreterUtil.operationsEqual(it, jvmConstr)]
	//				if (xtendConstr == null && jvmConstr.parameters.size != 0)
	//					throw new IllegalArgumentException
	//
	//				// get actual object
	//				var IXtendObjectMarker object = null
	//				var XBlockExpression constructorExpression = if(xtendConstr != null &&
	//						xtendConstr.expression instanceof XBlockExpression) xtendConstr.expression as XBlockExpression else null
	//				if (constructorExpression != null && clazz.extends != null &&
	//					constructorExpression.expressions.head instanceof XFeatureCall &&
	//					(constructorExpression.expressions.head as XFeatureCall).feature instanceof JvmConstructor) {
	//					val newCall = constructorExpression.expressions.head as XFeatureCall
	//					object = executeConstructorCall(newCall.feature as JvmConstructor,
	//						interpreter.evaluateArgumentExpressions(newCall.feature as JvmConstructor,
	//							newCall.actualArguments, context, CancelIndicator.NullImpl), allInterfaces, handler, classFqn) as IXtendObjectMarker
	//				} else {
	//					var newClass = clazz.extends?.type as JvmDeclaredType
	//					if (newClass == null)
	//						newClass = jvmTypes.findDeclaredType(Object, clazz) as JvmDeclaredType
	//					val constr = newClass.declaredConstructors.findFirst[parameters.empty]
	//
	//					object = executeConstructorCall(constr, #[], allInterfaces, handler, classFqn) as IXtendObjectMarker
	//				}
	//
	//				val state = object.objectState
	//
	//				//initialize member variables
	//				//TODO: should this be done before calling the super constructor?
	//				//probably not? it can't?
	//				for (f : clazz.members.filter(XtendField).filter[!static]) {
	//					val fieldFqn = type + "." + f.name
	//					if (f.initialValue != null) {
	//						val value = interpreter.internalEvaluate(f.initialValue, new ChattyEvaluationContext,
	//							CancelIndicator.NullImpl)
	//						state.put(fieldFqn, value)
	//					} else {
	//						state.put(fieldFqn, null)
	//					}
	//				}
	//
	//				// execute rest of constructor
	//				if (constructorExpression != null) {
	//					context.newValue(QualifiedName.create("this"), object)
	//					val first = constructorExpression.expressions.head
	//					var Iterable<XExpression> todo = null
	//					if (first instanceof XFeatureCall && (first as XFeatureCall).feature instanceof JvmConstructor)
	//						todo = constructorExpression.expressions.tail
	//					else
	//						todo = constructorExpression.expressions
	//					for (expr : todo) {
	//						interpreter.internalEvaluate(expr, context, CancelIndicator.NullImpl)
	//					}
	//				}
	//
	//				return object
	//			} else {
	//				throw new IllegalStateException
	//			}
	//		}
	//	}
	override fillAnonymousClassMethodContext(IEvaluationContext context, JvmOperation op, Object object) {
		val result = context.fork
		val callerContext = (anonymousClassContexts.get(object) as ChattyEvaluationContext).contents
		val existingValues = (context as ChattyEvaluationContext).contents.keySet
		for (name : callerContext.keySet.filter[it != "this"]) {
			if (!existingValues.contains(name)) {
				result.newValue(QualifiedName.create(name), callerContext.get(name))
			}
		}
		if (callerContext.containsKey("this")) {
			var counter = 0
			while (existingValues.contains("this_" + counter))
				counter++
			result.newValue(QualifiedName.create("this_" + counter), callerContext.get("this"))
		}
		result
	}

	override getClass(JvmType type, int arrayDims) {
		try {
			super.getClass(type, arrayDims)
		} catch (ClassNotFoundException e) {
			val basicClass = type.qualifiedName.createdClass
			if (arrayDims < 1)
				return basicClass
			else {

				//this is hacky
				//i'm sorry
				val int[] dims = newIntArrayOfSize(arrayDims)
				for (i : 0 ..< arrayDims)
					dims.set(i, 0)
				Array.newInstance(basicClass, dims).class
			}
		}
	}

	def protected Class<?> getCreatedClass(String fqn) {

		//		try {
		//			classFinder.forName(fqn)
		//			throw new IllegalArgumentException
		//		} catch (ClassNotFoundException e) {
		//			//good
		//		}
		if (classManager.canInterpretClass(fqn)) {
			val clazz = classManager.getClassForName(fqn)
			if (createdClasses.containsKey(clazz)) {
				if (compiledClasses.containsKey(createdClasses.get(clazz)))
					return compiledClasses.get(createdClasses.get(clazz))
				else {
					val created = createdClasses.get(clazz)
					val compiled = created.compile
					return compiled
				}
			} else {
				val ct = fqn.ctClass
				val result = ct.compile
				return result
			}
		} else {
			throw new IllegalStateException
		}
	}

	def protected Class<?> compile(CtClass ct) {
		try {
			val result = ct.toClass(classManager.configuredClassLoader)
			compiledClasses.put(ct, result)
			return result
		} catch (CannotCompileException e) {
			if (e.cause instanceof NoClassDefFoundError) {
				val error = e.cause as NoClassDefFoundError
				val missingClassFqn = error.message.replaceAll("/", ".")
				val missingClass = classManager.getClassForName(missingClassFqn)
				val missingCt = createdClasses.get(missingClass)
				if (missingCt == null)
					throw new IllegalStateException("Missing CtClass " + missingClassFqn)
				missingCt.compile
				return ct.compile
			} else {
				throw e
			}
		}
	}

	def protected String getDefaultConstructorCallString(String className) {

		return '''{
			super();
			org.nanosite.xtendency.interpreter.SimulatedObjectRepresentationStrategy.executeConstructor("«this.toString»", $0, "«className»", -1, 
				new java.lang.Object[0]);
		}'''
	}

	def protected String getConstructorCallString(XtendConstructor constr, int constructorIndex) {
		val constructorExpression = constr.expression as XBlockExpression
		val first = constructorExpression.expressions.head
		var Iterable<XExpression> restConstr = null
		var XFeatureCall superCall = null
		if (first instanceof XFeatureCall && (first as XFeatureCall).feature instanceof JvmConstructor) {
			restConstr = constructorExpression.expressions.tail
			superCall = first as XFeatureCall
		} else {
			restConstr = constructorExpression.expressions
		}

		return '''{
		«IF superCall != null»
			«IF (superCall.feature as JvmConstructor).declaringType.qualifiedName == constr.declaringType.qualifiedName»this(«ELSE»super(«ENDIF»
			«FOR p : (superCall.feature as JvmConstructor).parameters SEPARATOR ", "»
				(«p.parameterType.qualifiedName»)org.nanosite.xtendency.interpreter.SimulatedObjectRepresentationStrategy.getConstructorArgument("«this.
			toString»", «(superCall.feature as JvmConstructor).parameters.indexOf(p)», «constructorIndex», "«constr.
			declaringType.qualifiedName»", 
				new java.lang.Object[]{
					«FOR i : 0 ..< constr.parameters.size SEPARATOR ", "»
						«IF constr.parameters.get(i).parameterType.type instanceof JvmPrimitiveType»new «constr.parameters.get(i).
			parameterType.type.boxedName»($«i + 1»)«ELSE»$«i + 1»«ENDIF»
					«ENDFOR»})
			«ENDFOR»
			);
		«ELSE»
			super();
		«ENDIF»
		
			org.nanosite.xtendency.interpreter.SimulatedObjectRepresentationStrategy.executeConstructor("«this.toString»", $0, "«constr.
			declaringType.qualifiedName»", «constructorIndex», 
			new java.lang.Object[]{
				«FOR i : 0 ..< constr.parameters.size SEPARATOR ", "»
					«IF constr.parameters.get(i).parameterType.type instanceof JvmPrimitiveType»new «constr.parameters.get(i).
			parameterType.type.boxedName»($«i + 1»)«ELSE»$«i + 1»«ENDIF»
				«ENDFOR»
			});
		
		}'''
	}

	def protected String getBoxedName(JvmType t) {
		val type = t as JvmPrimitiveType
		return switch (type.simpleName) {
			case 'double': "Double"
			case 'int': "Integer"
			case 'long': "Long"
			case 'float': "Float"
			case 'boolean': 'Boolean'
			case 'short': "Short"
			case 'char': "Character"
		}
	}

	def static void executeConstructor(String sorsId, Object instance, String className, int constructorIndex,
		Object[] args) {
		val sors = instances.get(sorsId)

		// initialize fields
		val clazz = sors.classManager.getClassForName(className)
		val basicContext = new ChattyEvaluationContext
		basicContext.newValue(QualifiedName.create("this"), instance)
		for (f : clazz.members.filter(XtendField).filter[initialValue != null]) {
			val newContext = basicContext.fork
			val value = sors.interpreter.internalEvaluate(f.initialValue, newContext, CancelIndicator.NullImpl)
			sors.setFieldForSimulatedClass(instance, className, f.name, value)
		}

		if (constructorIndex > -1) {

			// execute rest constructor
			val constr = clazz.members.filter(XtendConstructor).toList.get(constructorIndex)
			val constructorExpression = constr.expression as XBlockExpression
			val first = constructorExpression.expressions.head
			var Iterable<XExpression> todo = null
			if (first instanceof XFeatureCall && (first as XFeatureCall).feature instanceof JvmConstructor)
				todo = constructorExpression.expressions.tail
			else
				todo = constructorExpression.expressions

			val constructorContext = basicContext.fork

			for (i : 0 ..< args.size) {
				constructorContext.newValue(QualifiedName.create(constr.parameters.get(i).name), args.get(i))
			}

			for (expr : todo) {
				sors.interpreter.internalEvaluate(expr, constructorContext, CancelIndicator.NullImpl)
			}
		}
	}

	def static Object getConstructorArgument(String sorsId, int argIndex, int constructorIndex, String className,
		Object[] args) {
		val sors = instances.get(sorsId)
		val clazz = sors.classManager.getClassForName(className)
		val constr = clazz.members.filter(XtendConstructor).toList.get(constructorIndex)
		val superCall = (constr.expression as XBlockExpression).expressions.head as XFeatureCall

		if (constr.parameters.size != args.size)
			throw new IllegalStateException

		val context = new ChattyEvaluationContext
		for (i : 0 ..< constr.parameters.size) {
			context.newValue(QualifiedName.create(constr.parameters.get(i).name), args.get(i))
		}

		sors.interpreter.internalEvaluate(superCall.actualArguments.get(argIndex), context, CancelIndicator.NullImpl)
	}

	def static Object executeMethod(String sorsId, String className, String methodIdentifier, Object inst,
		Object[] args) {
		val sors = instances.get(sorsId)
		val clazz = sors.jvmTypes.findDeclaredType(className, sors.classManager.resourceSet.resources.head.contents.head) as JvmDeclaredType

		val op = clazz.declaredOperations.findFirst[customIdentifier == methodIdentifier]
		sors.interpreter.invokeOperation(op, inst, args, new NullEvaluationContext, CancelIndicator.NullImpl)
	}

	def protected CtClass getCtClass(String fqn) {
		if (fqn === null)
			return CtClass.voidType
		try {
			return pool.get(fqn)
		} catch (NotFoundException e) {
			if (classManager.canInterpretClass(fqn)) {
				val clazz = classManager.getClassForName(fqn)
				return createCtClass(clazz as XtendClass, fqn)
			} else {
				throw new IllegalArgumentException
			}
		}
	}

	def protected void setFieldForSimulatedClass(Object instance, String className, String fieldName, Object value) {
		val clazz = className.createdClass
		val field = clazz.getDeclaredField(fieldName)
		field.accessible = true
		field.set(instance, value)
	}

	def protected Object getFieldForSimulatedClass(Object instance, String className, String fieldName) {
		val clazz = className.createdClass
		val field = clazz.getDeclaredField(fieldName)
		field.accessible = true
		field.get(instance)
	}

	def protected create newClass : pool.makeClass(superType + clazz.hashCode) createCtClass(AnonymousClass clazz,
		String superType) {
	}

	def protected create newClass : pool.makeClass(fqn) createCtClass(XtendClass clazz, String fqn) {
		createdClasses.put(clazz, newClass)
		val superClassName = clazz.extends?.qualifiedName ?: "java.lang.Object"
		newClass.superclass = superClassName.getCtClass

		for (i : clazz.implements) {
			newClass.addInterface(i.qualifiedName.getCtClass)
		}

		try {

			// if superclass is available in java
			val javaSuperClass = classFinder.forName(superClassName)

			// create aliases for java-only methods so we can call them if we must, even if they're overridden
			val accessibleMethods = new HashMap<String, Method>

			// first get all relevant methods (no duplicates, just the highest version)
			for (var c = javaSuperClass; c != null; c = c.superclass) {
				for (m : c.declaredMethods.filter[
					!Modifier.isFinal(modifiers) && (Modifier.isPublic(modifiers) || Modifier.isProtected(modifiers))]) {
					if (!accessibleMethods.containsKey(m.toString))
						accessibleMethods.put(m.toString, m)
				}
			}

			// then add an accessor method for each of them
			for (m : accessibleMethods.values) {
				val newName = m.customIdentifier
				val body = '''{«IF m.returnType != Void.TYPE»return («m.returnType.canonicalName»)«ENDIF»super.«m.name»(«FOR i : 0 ..<
					m.parameterTypes.size SEPARATOR ", "»$«i + 1»«ENDFOR»);}'''
				val newMethod = CtNewMethod.make(m.returnType.canonicalName.ctClass, newName,
					m.parameterTypes.map[canonicalName.ctClass], m.exceptionTypes.map[canonicalName.ctClass], body,
					newClass)
				newClass.addMethod(newMethod)
			}
		} catch (ClassNotFoundException e) {
			//empty else branch
		}

		// we take the jvmType because the XtendClass does not contain correct return types
		val jvmType = jvmTypes.findDeclaredType(clazz.qualifiedName, clazz) as JvmDeclaredType
		for (m : jvmType.declaredOperations) {
			val body = '''{«IF !(m.returnType.type instanceof JvmVoid)»return («m.returnType.qualifiedName»)«ENDIF»org.nanosite.xtendency.interpreter.SimulatedObjectRepresentationStrategy.executeMethod("«this.
				toString»", "«clazz.qualifiedName»", "«m.customIdentifier»", $0, «IF m.parameters.empty»new java.lang.Object[0]«ELSE»
				new java.lang.Object[]{
					«FOR i : 0 ..< m.parameters.size SEPARATOR ", "»
					«IF m.parameters.get(i).parameterType.type instanceof JvmPrimitiveType»new «m.parameters.get(i).parameterType.type.
				boxedName»($«i + 1»)«ELSE»$«i + 1»«ENDIF»
					«ENDFOR»
				}«ENDIF»); }'''
			val newMethod = CtNewMethod.make(
				if(m.returnType.type instanceof JvmVoid) CtClass.voidType else m.returnType.qualifiedName.ctClass,
				m.simpleName, m.parameters.map[parameterType.qualifiedName.ctClass],
				m.exceptions.map[qualifiedName.ctClass], body, newClass)
			try {
				newClass.addMethod(newMethod)

			} catch (DuplicateMemberException e) {
				throw e
			}
		}

		for (f : clazz.members.filter(XtendField)) {
			val newField = new CtField(f.type.qualifiedName.ctClass, f.name, newClass)
			newClass.addField(newField)
		}

		val constructors = clazz.members.filter(XtendConstructor).toList
		if (constructors.empty) {
			val body = getDefaultConstructorCallString(clazz.qualifiedName)
			val newConstructor = CtNewConstructor.make(#[], #[], body, newClass)
			newClass.addConstructor(newConstructor)
		} else {
			val constructorsToDo = constructors.sort(
				[ XtendConstructor c1, XtendConstructor c2 |
					val this1 = c1.hasThisCall
					val this2 = c2.hasThisCall
					if (this1 == this2)
						return 0
					else if (this1)
						return 1
					else
						return -1
				])
			for (c : constructorsToDo) {
				val body = c.getConstructorCallString(constructors.indexOf(c))

				val newConstructor = CtNewConstructor.make(c.parameters.map[parameterType.qualifiedName.ctClass],
					c.exceptions.map[qualifiedName.ctClass], body, newClass)
				newClass.addConstructor(newConstructor)
			}
		}

	}

	protected static def String getCustomIdentifier(Method m) {
		val result = new StringBuilder(DELEGATE_METHOD_MARKER)
		result.append(m.name)
		for (p : m.parameterTypes) {

			//TODO: is the simple name enough?
			result.append(p.simpleName)
		}
		result.toString
	}

	protected static def String getCustomIdentifier(JvmOperation m) {
		val result = new StringBuilder(DELEGATE_METHOD_MARKER)
		result.append(m.simpleName)
		for (p : m.parameters) {

			//TODO: is the simple name enough?
			result.append(p.parameterType.simpleName)
		}
		result.toString
	}

	protected def boolean hasThisCall(XtendConstructor c) {
		val content = c.expression as XBlockExpression
		if (content.expressions.empty) {
			false
		} else {
			val first = content.expressions.head
			if (first instanceof XFeatureCall && (first as XFeatureCall).feature instanceof JvmConstructor) {
				return c.declaringType.qualifiedName ==
					((first as XFeatureCall).feature as JvmConstructor).declaringType.qualifiedName
			} else {
				false
			}
		}
	}

	override getJavaOnlyMethod(Object instance, JvmOperation method) {
		instance.class.getMethod(method.customIdentifier,
			method.parameters.map[classFinder.forName(parameterType.qualifiedName)])
	}

}
