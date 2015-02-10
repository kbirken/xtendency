package org.nanosite.xtendency.interpreter.ors.javassist

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
import org.eclipse.xtend.core.jvmmodel.IXtendJvmAssociations
import com.google.inject.Inject
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtend.core.xtend.XtendInterface
import org.eclipse.xtend.core.xtend.XtendEnum
import org.eclipse.xtend.core.xtend.XtendEnumLiteral
import javassist.CtConstructor
import javassist.CtPrimitiveType
import javassist.bytecode.AnnotationsAttribute
import javassist.CtBehavior
import org.eclipse.xtext.common.types.JvmAnnotationReference
import org.eclipse.xtext.xbase.annotations.xAnnotations.XAnnotation
import javassist.bytecode.annotation.Annotation
import org.eclipse.xtext.common.types.JvmStringAnnotationValue
import javassist.bytecode.annotation.StringMemberValue
import org.eclipse.xtext.common.types.JvmIntAnnotationValue
import javassist.bytecode.annotation.IntegerMemberValue
import org.eclipse.xtext.common.types.JvmTypeAnnotationValue
import javassist.bytecode.annotation.ClassMemberValue
import org.nanosite.xtendency.interpreter.IObjectRepresentationStrategy
import org.nanosite.xtendency.interpreter.ors.java.CompiledJavaObjectRepresentationStrategy
import org.nanosite.xtendency.interpreter.ChattyEvaluationContext
import org.nanosite.xtendency.interpreter.IInterpreterAccess
import org.nanosite.xtendency.interpreter.IClassManager

class JavassistClassObjectRepresentationStrategy extends CompiledJavaObjectRepresentationStrategy implements IObjectRepresentationStrategy {
	protected static final String DELEGATE_METHOD_MARKER = "__delegate_"

	protected Map<Pair<Object, XtendFunction>, Map<List<?>, Object>> createCaches = new HashMap

	protected Map<Object, IEvaluationContext> anonymousClassContexts = new IdentityHashMap

	protected Map<XtendTypeDeclaration, CtClass> createdClasses = new HashMap
	protected Map<CtClass, Class<?>> compiledClasses = new HashMap

	protected ClassPool pool

	protected Set<XtendTypeDeclaration> initializedClasses = new HashSet

	protected HidingClassLoader hidingLoader
	protected ClassLoader definingLoader

	public static Map<String, JavassistClassObjectRepresentationStrategy> instances = new HashMap<String, JavassistClassObjectRepresentationStrategy>

	@Inject
	IXtendJvmAssociations jvmAssociations

	override protected getCreateCache(Object receiver, XtendFunction func) {
		if (createCaches.containsKey(receiver -> func)) {
			createCaches.get(receiver -> func)
		} else {
			try{
				super.getCreateCache(receiver, func)
			}catch(NoSuchFieldException e){
				println ("field was " + func.name + " " + func.declaringType.qualifiedName)
				throw e
			}
		}
	}

	override executeConstructorCall(XConstructorCall call, JvmConstructor constr, List<?> arguments) {
		if (!classManager.canInterpretClass(constr.declaringType.qualifiedName)) {
			return super.executeConstructorCall(call, constr, arguments)
		} else {
			val clazz = constr.declaringType.qualifiedName.createdClass
			val constructor = clazz.constructors.findFirst[constructorsEqual(constr, it)]
			if (constructor == null)
				throw new NoSuchMethodException("Could not find constructor " + constr.getIdentifier());
			constructor.setAccessible(true);
			val result = constructor.newInstance(arguments.toArray);
			return result;
		}
	}

	override getFieldValue(Object object, JvmField jvmField) {
		if (!classManager.canInterpretClass(jvmField.declaringType.qualifiedName)) {
			super.getFieldValue(object, jvmField)
		} else {
			object.getFieldForSimulatedClass(jvmField.declaringType.qualifiedName, jvmField.simpleName)
		}
	}

	override getStaticFieldValue(JvmField jvmField) {
		val fqn = jvmField.declaringType.qualifiedName
		if (!classManager.canInterpretClass(fqn)) {
			super.getStaticFieldValue(jvmField)
		} else {
			val f = fqn.createdClass.getDeclaredField(jvmField.simpleName)
			f.accessible = true
			f.get(null)
		}
	}

	override setFieldValue(Object object, JvmField jvmField, Object value) {
		if (!classManager.canInterpretClass(jvmField.declaringType.qualifiedName)) {
			super.setFieldValue(object, jvmField, value)
		} else {
			setFieldForSimulatedClass(object, jvmField.declaringType.qualifiedName, jvmField.simpleName, value)
		}
	}

	override setStaticFieldValue(JvmField jvmField, Object value) {
		val fqn = jvmField.declaringType.qualifiedName
		if (!classManager.canInterpretClass(fqn)) {
			super.setStaticFieldValue(jvmField, value)
		} else {
			val f = fqn.createdClass.getDeclaredField(jvmField.simpleName)
			f.accessible = true
			f.set(null, value)
		}
	}

	override initializeClass(XtendTypeDeclaration clazz) {
		if (initializedClasses.contains(clazz))
			return;
		initializedClasses.add(clazz)
		val javaClass = clazz.qualifiedName.createdClass

		for (f : clazz.members.filter(XtendField).filter[static]) {
			var Object value = null
			if (f.initialValue != null) {
				value = interpreter.evaluate(f.initialValue, new ChattyEvaluationContext,
					CancelIndicator.NullImpl)
			}
			val javaF = javaClass.getDeclaredField(f.name)
			javaF.accessible = true
			try {
				javaF.set(null, value)
			} catch (NullPointerException e) {
				throw e
			}
		}
	}

	override init(JavaReflectAccess reflectAccess, ClassFinder classFinder, IClassManager classManager,
		TypeReferences jvmTypes, IInterpreterAccess interpreter) {
		super.init(reflectAccess, classFinder, classManager, jvmTypes, interpreter)
		pool = new ClassPool(null)
        pool.appendSystemPath
		//createCaches.clear
		instances.put(this.toString, this)
		pool.appendClassPath(new DelegatingLoaderClassPath(classManager.configuredClassLoader))
		hidingLoader = new HidingClassLoader(classManager.configuredClassLoader)
		hidingLoader.hideClasses(classManager.availableClasses)
		definingLoader = new NullClassLoader(hidingLoader)
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
		if (!classManager.canInterpretClass(typeFQN)) {
			clazz = classFinder.forName(typeFQN)
		} else {
			clazz = getCreatedClass(typeFQN)
		}

		clazz.isInstance(obj)
	}

	override executeAnonymousClassConstructor(AnonymousClass clazz, List<?> arguments, IEvaluationContext context) {
		var Class<?> javaClass = null
		if (createdClasses.containsKey(clazz)) {
			if (compiledClasses.containsKey(createdClasses.get(clazz)))
				javaClass = compiledClasses.get(createdClasses.get(clazz))
			else {
				val created = createdClasses.get(clazz)
				val compiled = created.compile
				javaClass = compiled
			}
		} else {
			val ct = clazz.createCtClass
			val result = ct.compile
			javaClass = result
		}

		val officialType = clazz.constructorCall.constructor.declaringType.identifier
		val calledType = clazz.constructorCall.constructor.declaringType.superTypes.head.type as JvmGenericType

		val dummyConstructor = clazz.constructorCall.constructor

		var JvmConstructor constructor = null
		val javaConstr = javaClass.declaredConstructors.head

		var Object object = if (arguments.empty)
				javaConstr.newInstance
			else
				javaConstr.newInstance(
					interpreter.evaluateArgumentExpressions(clazz.constructorCall.constructor,
						clazz.constructorCall.arguments, context, CancelIndicator.NullImpl).toArray)

		classManager.addAnonymousClass(officialType, clazz)
		anonymousClassContexts.put(object, context)

		object
	}

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
		if (!classManager.canInterpretClass(type.qualifiedName)) {
			super.getClass(type, arrayDims)
		} else {
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
			val result = pool.toClass(ct, definingLoader)
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
			«class.canonicalName».executeConstructor("«this.toString»", $0, "«className»", -1, 
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

		val result = '''{
		«IF superCall != null»
			«IF (superCall.feature as JvmConstructor).declaringType.qualifiedName == constr.declaringType.qualifiedName»this(«ELSE»super(«ENDIF»
			«FOR p : (superCall.feature as JvmConstructor).parameters SEPARATOR ", "»
				(«p.parameterType.qualifiedName»)«class.canonicalName».getConstructorArgument("«this.
			toString»", «(superCall.feature as JvmConstructor).parameters.indexOf(p)», «constructorIndex», "«constr.
			declaringType.qualifiedName»", $args)
			«ENDFOR»
			);
		«ELSE»
			super();
		«ENDIF»
		
			«class.canonicalName».executeConstructor("«this.toString»", $0, "«constr.
			declaringType.qualifiedName»", «constructorIndex», $args);
		
		}'''
		result
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
			val value = sors.interpreter.evaluate(f.initialValue, newContext, CancelIndicator.NullImpl)
			sors.setFieldForSimulatedClass(instance, className, f.name ?: sors.jvmAssociations.getJvmField(f).simpleName, value)
		}
		
		//create createCaches
		val createMethods = clazz.members.filter(XtendFunction).filter[createExtensionInfo != null]

		for (m : createMethods){
			sors.createCaches.put(instance -> m, new HashMap)
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
				sors.interpreter.evaluate(expr, constructorContext, CancelIndicator.NullImpl)
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

		sors.interpreter.evaluate(superCall.actualArguments.get(argIndex), context, CancelIndicator.NullImpl)
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
		if (!classManager.canInterpretClass(fqn)) {
			classManager.configuredClassLoader.loadClass("org.nanosite.xtendency.interpreter.tests.input.JavaA")
			return pool.get(fqn)
		} else {
			val clazz = classManager.getClassForName(fqn)
			return createCtClass(clazz)
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

	def protected dispatch create newInterface : pool.makeInterface(clazz.qualifiedName) createCtClass(
		XtendInterface clazz) {
		createdClasses.put(clazz, newInterface)

		// we take the jvmType because the XtendClass does not contain correct return types
		val jvmType = jvmAssociations.getInferredType(clazz) //jvmTypes.findDeclaredType(clazz.qualifiedName, clazz) as JvmDeclaredType
		for (m : jvmType.declaredOperations) {
			val newMethod = CtNewMethod.abstractMethod(
				if(m.returnType.type instanceof JvmVoid) CtClass.voidType else m.returnType.qualifiedName.ctClass,
				m.simpleName, m.parameters.map[parameterType.type.qualifiedName.ctClass],
				m.exceptions.map[qualifiedName.ctClass], newInterface)
			newInterface.addMethod(newMethod)
		}

		for (f : clazz.members.filter(XtendField)) {
			val newField = new CtField(f.type.qualifiedName.ctClass, f.name, newInterface)
			if (f.static)
				newField.modifiers = newField.modifiers.bitwiseOr(Modifier.STATIC)
			newInterface.addField(newField)
		}
	} 

	def protected dispatch create newClass : pool.makeClass(clazz.qualifiedName) createCtClass(XtendClass clazz) {
		createdClasses.put(clazz, newClass)
		val superClassName = clazz.extends?.qualifiedName ?: "java.lang.Object"
		val interfaceNames = clazz.implements.map[qualifiedName]
		clazz.createCtClass(newClass, superClassName, interfaceNames)
	}

	def protected dispatch create newEnum : pool.makeClass(enm.qualifiedName) createCtClass(XtendEnum enm) {
		createdClasses.put(enm, newEnum)
		val superClassName = "java.lang.Enum"
		enm.createCtClass(newEnum, superClassName, #[])
	}

	def protected dispatch create newClass : pool.makeClass(clazz.constructorCall.constructor.declaringType.identifier) createCtClass(
		AnonymousClass clazz) {
		createdClasses.put(clazz, newClass)
		val calledType = clazz.constructorCall.constructor.declaringType.superTypes.head.type as JvmGenericType

		val interfaceNames = new ArrayList<String>
		var String superClassName = null

		val dummyConstructor = clazz.constructorCall.constructor

		var JvmConstructor constructor = null

		//find actual constructor
		//which is the called constructor of the superclass
		//or Object() if the supertype is an interface
		if (calledType.interface) {
			constructor = (jvmTypes.findDeclaredType(Object, clazz) as JvmDeclaredType).declaredConstructors.findFirst[
				parameters.empty]
			interfaceNames += calledType.qualifiedName
			superClassName = "java.lang.Object"
		} else {
			constructor = calledType.getDeclaredConstructors.findFirst[
				parameters.size == dummyConstructor.parameters.size && (0 ..< parameters.size).forall[i|
					parameters.get(i).parameterType.qualifiedName ==
						dummyConstructor.parameters.get(i).parameterType.qualifiedName]]
			superClassName = calledType.qualifiedName
		}

		clazz.createCtClass(newClass, superClassName, interfaceNames)

		// add called constructor
		if (calledType.interface) {
			newClass.addConstructor(CtNewConstructor.defaultConstructor(newClass))
		} else {
			val newConstructor = CtNewConstructor.make(constructor.parameters.map[parameterType.qualifiedName.ctClass],
				constructor.exceptions.map[type.qualifiedName.ctClass], "{super($$);}", newClass)
			newClass.addConstructor(newConstructor)
		}
	}
	
	def protected getAnnotation(JvmAnnotationReference a, CtClass c){
		val constPool = c.classFile.constPool
		val att = new AnnotationsAttribute(constPool, AnnotationsAttribute.visibleTag)
		val ann = new Annotation(a.annotation.qualifiedName, constPool)
		for (av : a.values){
			switch(av){
				JvmStringAnnotationValue:{
					ann.addMemberValue(av.valueName, new StringMemberValue(av.values.head, constPool))
				}
				JvmIntAnnotationValue : {
					ann.addMemberValue(av.valueName, new IntegerMemberValue(av.values.head, constPool))
				}
				JvmTypeAnnotationValue : {
					ann.addMemberValue(av.valueName, new ClassMemberValue(av.values.head.qualifiedName, constPool))
				}
				default : {
					//TODO
				}
			}
		}
		att.addAnnotation(ann)
		att
	}

	def protected createCtClass(XtendTypeDeclaration clazz, CtClass newClass, String superClassName,
		List<String> interfaceNames) {

		newClass.superclass = superClassName.getCtClass

		for (i : interfaceNames) {
			newClass.addInterface(i.getCtClass)
		}

		if (!classManager.canInterpretClass(superClassName) && !(clazz instanceof XtendEnum)) {
			val javaSuperClass = classFinder.forName(superClassName)

			// create aliases for java-only methods so we can call them if we must, even if they're overridden
			val accessibleMethods = new HashMap<String, Method>

			// first get all relevant methods (no duplicates, just the highest version)
			for (var c = javaSuperClass; c != null; c = c.superclass) {
				for (m : c.declaredMethods.filter[
					!Modifier.isAbstract(modifiers) && !Modifier.isFinal(modifiers) && !Modifier.isStatic(modifiers) &&
						(Modifier.isPublic(modifiers) || Modifier.isProtected(modifiers))]) {
					if (!accessibleMethods.containsKey(m.customIdentifier))
						accessibleMethods.put(m.customIdentifier, m)
				}
			}

			// then add an accessor method for each of them
			for (m : accessibleMethods.values) {
				val newName = m.customIdentifier
				val body = '''{«IF m.returnType != Void.TYPE»return («m.returnType.canonicalName»)«ENDIF»super.«m.name»($$);}'''
				val newMethod = CtNewMethod.make(m.returnType.canonicalName.ctClass, DELEGATE_METHOD_MARKER + newName,
					m.parameterTypes.map[canonicalName.ctClass], m.exceptionTypes.map[canonicalName.ctClass], body,
					newClass)
				newClass.addMethod(newMethod)
			}
		}
		
		//annotations for the class
		for (a : jvmAssociations.getInferredType(clazz).annotations){
			newClass.classFile.addAttribute(a.getAnnotation(newClass))
		}

		// we take the jvmType because the XtendClass does not contain correct return types
		val jvmType = jvmAssociations.getInferredType(clazz) //jvmTypes.findDeclaredType(clazz.qualifiedName, clazz) as JvmDeclaredType
		for (m : jvmType.declaredOperations) {
			if (m.abstract) {
				val newMethod = CtNewMethod.abstractMethod(
					if(m.returnType.type instanceof JvmVoid) CtClass.voidType else m.returnType.qualifiedName.ctClass,
					m.simpleName, m.parameters.map[parameterType.type.qualifiedName.ctClass],
					m.exceptions.map[qualifiedName.ctClass], newClass)
				for (a : m.annotations){
					newMethod.methodInfo.addAttribute(a.getAnnotation(newClass))
				}
				newClass.addMethod(newMethod)
			} else {
				val body = '''{
				«IF !(m.returnType.type instanceof JvmVoid)»return «IF m.returnType.primitive»(«ENDIF»(«m.returnType.
					wrapperTypeName»)«ENDIF»
				«class.canonicalName».executeMethod("«this.toString»", "«clazz.
					qualifiedName»", "«m.customIdentifier»", «IF m.static»null«ELSE»$0«ENDIF», $args)
				«IF m.returnType.primitive»).«m.returnType.qualifiedName»Value()«ENDIF»
				; 
				}'''
				val newMethod = new CtMethod(
					if(m.returnType.type instanceof JvmVoid) CtClass.voidType else m.returnType.qualifiedName.ctClass,
					m.simpleName, m.parameters.map[parameterType.type.qualifiedName.ctClass], newClass)
				if (m.static)
					newMethod.modifiers = newMethod.modifiers.bitwiseOr(Modifier.STATIC)
				newMethod.exceptionTypes = m.exceptions.map[qualifiedName.ctClass]
				newMethod.body = body
				for (a : m.annotations){
					newMethod.methodInfo.addAttribute(a.getAnnotation(newClass))
				}
				newClass.addMethod(newMethod)
			}
		}

		for (f : clazz.members.filter(XtendField)) {
			val newField = new CtField(f.type.qualifiedName.ctClass, f.name ?: this.jvmAssociations.getJvmField(f).simpleName, newClass)
			if (f.static)
				newField.modifiers = newField.modifiers.bitwiseOr(Modifier.STATIC)
			for (a : jvmAssociations.getJvmField(f).annotations){
				newField.fieldInfo.addAttribute(a.getAnnotation(newClass))
			}
			newClass.addField(newField)
		}

		if (clazz instanceof XtendEnum) {
			val newConstructor = new CtConstructor(#["java.lang.String".ctClass, CtPrimitiveType.intType], newClass)
			newConstructor.modifiers = newConstructor.modifiers.bitwiseOr(Modifier.PRIVATE)
			newConstructor.body = "{super($1, $2);}"
			newClass.addConstructor(newConstructor)
		} else {
			val constructors = clazz.members.filter(XtendConstructor).toList
			if (constructors.empty && !(clazz instanceof AnonymousClass)) {
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
					for (a : jvmAssociations.getInferredConstructor(c).annotations){
						newConstructor.methodInfo.addAttribute(a.getAnnotation(newClass))
					}
					newClass.addConstructor(newConstructor)
				}
			}
		}

		if (clazz instanceof XtendEnum) {
			val literals = clazz.members.filter(XtendEnumLiteral).toList
			for (el : literals) {
				val newField = new CtField(newClass, el.name, newClass)
				newField.modifiers = Modifier.STATIC.bitwiseOr(Modifier.PUBLIC).bitwiseOr(Modifier.FINAL)
				newClass.addField(newField, '''new «newClass.name»("«el.name»", «literals.indexOf(el)»)''')
			}
			val valuesField = new CtField(pool.get(newClass.name + "[]"), "VALUES", newClass)
			valuesField.modifiers = valuesField.modifiers.bitwiseOr(Modifier.STATIC).bitwiseOr(Modifier.PUBLIC).bitwiseOr(Modifier.FINAL)
			newClass.addField(valuesField, '''new «newClass.name»[] {«FOR el : literals SEPARATOR ", "»«el.name»«ENDFOR»}''')
		
//			val valueOfMethod = new CtMethod(newClass, "valueOf", #[pool.get("java.lang.String")], newClass)
//			valueOfMethod.modifiers = valueOfMethod.modifiers.bitwiseOr(Modifier.STATIC)
//			valueOfMethod.body = "{return java.lang.Enum.valueOf($class, $1); }"
//			newClass.addMethod(valueOfMethod)
//			
//			val valuesMethod = new CtMethod(pool.get(newClass.name + "[]"), "values", #[], newClass)
//			valuesMethod.modifiers = valuesMethod.modifiers.bitwiseOr(Modifier.STATIC)
//			valuesMethod.body = "{return VALUES;}"
//			newClass.addMethod(valuesMethod)
		}
	}

	protected static def String getCustomIdentifier(Method m) {
		val result = new StringBuilder(m.name)
		for (p : m.parameterTypes) {

			result.append(p.simpleName.replaceAll("\\[\\]", "Array"))
		}
		result.toString
	}

	protected static def String getCustomIdentifier(JvmOperation m) {
		val result = new StringBuilder(m.simpleName)
		for (p : m.parameters) {

			//TODO: is the simple name enough?
			result.append(p.parameterType.simpleName.replaceAll("\\[\\]", "Array"))
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
		instance.class.getMethod(DELEGATE_METHOD_MARKER + method.customIdentifier,
			method.parameters.map[classFinder.forName(parameterType.qualifiedName)])
	}

	def protected boolean isPrimitive(JvmTypeReference t) {
		t.type instanceof JvmPrimitiveType
	}

	def protected String getWrapperTypeName(JvmTypeReference t) {
		if (t.primitive) {
			switch (t.qualifiedName) {
				case 'boolean': 'Boolean'
				case 'int': 'Integer'
				case 'char': 'Character'
				case 'long': 'Long'
				case 'double': 'Double'
				case 'float': 'Float'
				case 'byte': 'Byte'
			}
		} else {
			t.qualifiedName
		}
	}

}
