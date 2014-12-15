package org.nanosite.xtendency.interpreter

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.HashMap
import java.util.List
import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.osgi.internal.loader.EquinoxClassLoader
import org.eclipse.xtend.core.richstring.DefaultIndentationHandler
import org.eclipse.xtend.core.richstring.RichStringProcessor
import org.eclipse.xtend.core.xtend.RichString
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendField
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.xtext.common.types.JvmDeclaredType
import org.eclipse.xtext.common.types.JvmField
import org.eclipse.xtext.common.types.JvmGenericType
import org.eclipse.xtext.common.types.JvmIdentifiableElement
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.interpreter.impl.EvaluationException
import org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter
import org.eclipse.xtext.xbase.typesystem.IBatchTypeResolver
import org.eclipse.xtext.xbase.XClosure
import java.lang.reflect.Proxy
import org.eclipse.xtext.xbase.XConstructorCall
import java.util.Stack
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationResult
import java.io.PrintWriter
import java.io.StringWriter
import java.io.BufferedReader
import java.io.StringReader
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.xbase.interpreter.impl.InterpreterCanceledException
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.common.types.JvmExecutable
import org.eclipse.xtext.xbase.XMemberFeatureCall
import org.eclipse.xtend.core.xtend.XtendConstructor
import org.eclipse.xtext.common.types.JvmConstructor
import java.lang.reflect.Method
import org.eclipse.xtext.common.types.util.TypeReferences
import org.eclipse.emf.common.notify.Notifier
import org.eclipse.xtend.core.xtend.AnonymousClass

import static extension org.nanosite.xtendency.interpreter.InterpreterUtil.*

class XtendInterpreter extends XbaseInterpreter {

	@Inject
	protected IBatchTypeResolver typeResolver

	@Inject
	protected RichStringProcessor richStringProcessor

	@Inject
	protected TypeReferences jvmTypes

	@Inject
	protected Provider<DefaultIndentationHandler> indentationHandler

	protected XtendTypeDeclaration currentType

	protected ClassLoader injectedClassLoader

	protected ClassLoader usedClassLoader

	protected IClassManager classManager

	@Inject
	protected IObjectRepresentationStrategy objectRep

	protected Stack<XAbstractFeatureCall> currentStackTrace = new Stack<XAbstractFeatureCall>

	protected extension InterpreterUtil util

	protected boolean calledCorrectly = false

	override void setClassLoader(ClassLoader cl) {
		if (cl instanceof EquinoxClassLoader) {
		}
		this.injectedClassLoader = cl
		super.classLoader = cl
		this.usedClassLoader = cl
	}

	override protected internalEvaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator) throws EvaluationException {

		//overridden to make method accessible for other classes in this package
		super.internalEvaluate(expression, context, indicator)
	}

	override evaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator) {
		if (!calledCorrectly)
			println(
				"Please use XtendInterpreter.evaluateMethod(..) to invoke a method. Using evaluate(..) directly may lead to errors or other unintended behaviour.")

		try {
			val result = internalEvaluate(expression, context,
				if(indicator != null) indicator else CancelIndicator.NullImpl);
			return new DefaultEvaluationResult(result, null);
		} catch (EvaluationException e) {
			val nl = System.getProperty("line.separator", "\n")
			val result = new StringBuilder
			val sw = new StringWriter()
			val pw = new PrintWriter(sw)
			e.cause.printStackTrace(pw)

			val br = new BufferedReader(new StringReader(sw.toString))
			var continueReading = true
			while (continueReading) {
				val current = br.readLine
				if (current == null || current.contains("sun.reflect.NativeMethodAccessor") ||
					current.contains("sun.reflect.GeneratedMethodAccessor") ||
					current.contains("org.nanosite.xtendency.tracer.core.") ||
					current.contains("org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter"))
					continueReading = false
				else
					result.append(current).append(nl)
			}

			val stackInOrder = currentStackTrace.reverse
			for (call : stackInOrder) {
				val op = call.getParent(XtendFunction)
				val clazz = op?.getParent(XtendClass)
				val file = clazz?.getParent(XtendFile)
				if (file != null) {
					val opName = clazz.qualifiedName + "." + op.name
					val filename = call.eResource.URI.lastSegment
					val node = NodeModelUtils.findActualNodeFor(call)
					result.append("\tat " + opName + "(" + filename + ":" + node.startLine + ")").append(nl)
				}
			}
			return new XtendEvaluationResult(null, e.getCause(), result.toString);
		} catch (InterpreterCanceledException e) {
			return null;
		} catch (Exception e) {
			if (e.class.simpleName == "ReturnValue") {
				val rvField = e.class.getDeclaredField("returnValue")
				rvField.accessible = true
				return new DefaultEvaluationResult(rvField.get(e), null)
			} else {
				throw e
			}

		}
	}

	def evaluateMethod(XtendFunction method, Object currentInstance, IClassManager classMgr,
		List<? extends Object> arguments) {
		if (method.static && currentInstance != null)
			throw new IllegalArgumentException
		if (!method.static && currentInstance == null)
			throw new IllegalArgumentException
		if (method.parameters.size != arguments.size)
			throw new IllegalArgumentException

		this.classManager = classMgr
		if (classMgr.configuredClassLoader == null)
			super.classLoader = classMgr.configureClassLoading(injectedClassLoader)
		else
			super.classLoader = classMgr.configuredClassLoader
		util = new InterpreterUtil(classFinder)

		val clazz = method.declaringType as XtendClass
		this.currentType = clazz
		classManager.recordClassUse(clazz.qualifiedName)

		currentStackTrace.clear

		objectRep.init(javaReflectAccess, classFinder, classMgr, jvmTypes, this)
		objectRep.initializeClass(clazz)

		val context = new ChattyEvaluationContext
		if (currentInstance != null)
			context.newValue(QualifiedName.create("this"), currentInstance)
		for (i : 0 ..< method.parameters.size) {
			context.newValue(QualifiedName.create(method.parameters.get(i).name), arguments.get(i))
		}

		calledCorrectly = true
		val result = evaluate(method.expression, context, CancelIndicator.NullImpl)
		calledCorrectly = false
		result
	}

	protected def Object _doEvaluate(RichString rs, IEvaluationContext context, CancelIndicator indicator) {
		val helper = createRichStringExecutor(context, indicator)

		richStringProcessor.process(rs, helper, indentationHandler.get)

		helper.result
	}

	protected def IRichStringExecutor createRichStringExecutor(IEvaluationContext context, CancelIndicator indicator) {
		new DefaultRichStringExecutor(this, context, indicator)
	}

	protected override Object doEvaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator) {
		if (expression instanceof RichString) {
			_doEvaluate(expression as RichString, context, indicator)
		}else if (expression instanceof AnonymousClass) {
			_doEvaluate(expression, context, indicator)
		} else {
			super.doEvaluate(expression, context, indicator)
		}
	}
	
	def Object _doEvaluate(AnonymousClass expression, IEvaluationContext context, CancelIndicator indicator){
		objectRep.executeAnonymousClassConstructor(expression, evaluateArgumentExpressions(expression.constructorCall.constructor, expression.constructorCall.arguments, context, indicator), context)
	}
	
	protected def getCurrentType(){
		currentType
	}
	
	protected def setCurrentType(XtendTypeDeclaration type){
		this.currentType = type
	}

	override protected evaluateArgumentExpressions(JvmExecutable executable, List<XExpression> expressions,
		IEvaluationContext context, CancelIndicator indicator) {
		println("evaluateargumentexpr " + executable)
		super.evaluateArgumentExpressions(executable, expressions, context, indicator)
	}

	override protected _doEvaluate(XConstructorCall constructorCall, IEvaluationContext context,
		CancelIndicator indicator) {
		val jvmConstructor = constructorCall.getConstructor
		val arguments = evaluateArgumentExpressions(jvmConstructor, constructorCall.getArguments(), context, indicator)
		
		return objectRep.executeConstructorCall(constructorCall, jvmConstructor, arguments)
	}

	protected def XtendConstructor getConstructor(XtendClass clazz, JvmConstructor constr) {
		val result = clazz.members.filter(XtendConstructor).findFirst[c|InterpreterUtil.operationsEqual(c, constr)]
		if (result != null)
			return result
		if (clazz.extends != null) {
			val parentClazz = classManager.getClassForName(clazz.extends.qualifiedName) as XtendClass
			return getConstructor(parentClazz, constr)
		}
		null
	}

	protected def Object invokeOperation(Notifier notifier, Method operation, Object receiver, Object[] argumentValues,
		Method javaOperation) {
		val jvmType = jvmTypes.findDeclaredType(operation.declaringClass, notifier) as JvmDeclaredType
		val jvmOperation = jvmType.declaredOperations.findFirst[it.operationsEqual(operation)]
		return invokeOperation(jvmOperation, receiver, argumentValues, new ChattyEvaluationContext,
			CancelIndicator.NullImpl, javaOperation, true)
	}

	protected override Object invokeOperation(JvmOperation operation, Object receiver, List<Object> argumentValues,
		IEvaluationContext context, CancelIndicator indicator) {
		invokeOperation(operation, receiver, argumentValues, context, indicator, null, true)
	}
	
	override protected _invokeFeature(JvmOperation operation, XAbstractFeatureCall featureCall, Object receiver, IEvaluationContext context, CancelIndicator indicator) {
		val operationArguments = getActualArguments(featureCall);
		val argumentValues = evaluateArgumentExpressions(operation, operationArguments, context, indicator);
		val polymorphic = if (featureCall.actualReceiver?.toString == "super") false else true
		return invokeOperation(operation, receiver, argumentValues, context, indicator, null, polymorphic);
	}

	protected def Object invokeOperation(JvmOperation operation, Object receiver, List<Object> argumentValues,
		IEvaluationContext context, CancelIndicator indicator, Method javaOperation, boolean polymorphicInvoke) {

		// to do polymorphism properly
		// find out which class the object actually has
		// then iterate through types
		var String calledTypeFqn = null
		var String calledTypeSimpleNonFinal = null

		if (receiver !== null) {
			val calledType = findCalledMethodType(operation, objectRep.getQualifiedClassName(receiver), polymorphicInvoke)

			//calledtype may be null if the class is not available in xtend
			if (calledType == null){
				if (javaOperation != null){
					return javaOperation.invoke(receiver, argumentValues.toArray)
				}else{
					return super.invokeOperation(operation, receiver, argumentValues, context, indicator)
				}
			}

			calledTypeFqn = calledType.key
			calledTypeSimpleNonFinal = calledType.value
		} else {
			calledTypeFqn = operation.declaringType.qualifiedName
			calledTypeSimpleNonFinal = operation.declaringType.simpleName
		}
		val op = operation.simpleName
		if (currentType != null) {
			val currentTypeName = currentType.qualifiedName
			val calledJvmType = jvmTypes.findDeclaredType(calledTypeFqn, currentType) as JvmDeclaredType
			val currentJvmType = if (currentType instanceof AnonymousClass)
				currentType.constructorCall.constructor.declaringType.superTypes.head.type as JvmDeclaredType
			else
				jvmTypes.findDeclaredType(currentTypeName, currentType) as JvmDeclaredType
			
			if (receiver === null && currentJvmType.isSubtypeOf(calledJvmType)) {
				val calledFunc = getCalledFunction(currentType, op, argumentValues.size, argumentValues)

				var IEvaluationContext newContext = new ChattyEvaluationContext
				newContext.newValue(QualifiedName.create("this"), context.getValue(QualifiedName.create("this")))
				
				if (currentType instanceof AnonymousClass)
					newContext = objectRep.fillAnonymousClassMethodContext(newContext, operation, context.getValue(QualifiedName.create("this")))
				return evaluateOperation(calledFunc, argumentValues, null, newContext, indicator)
			}
		}
		if (classManager.canInterpretClass(calledTypeFqn)) {
			val type = classManager.getClassForName(calledTypeFqn)
			val calledFunc = getCalledFunction(type, op, argumentValues.size, argumentValues)

			classManager.recordClassUse(calledTypeFqn)
			objectRep.initializeClass(type)
			var IEvaluationContext newContext = new ChattyEvaluationContext
			newContext.newValue(QualifiedName.create("this"), receiver)
			
			if (type instanceof AnonymousClass)
				newContext = objectRep.fillAnonymousClassMethodContext(newContext, operation, receiver)
			return evaluateOperation(calledFunc, argumentValues, type, newContext, indicator)
		}
		if (javaOperation != null){
			javaOperation.invoke(receiver, argumentValues.toArray)
		}else{
			super.invokeOperation(operation, receiver, argumentValues, context,
			indicator)
		}
		
	}

	// given an operation and the actual runtime type of an object, returns the FQN of the class which first implements it
	// i.e. does polymorphism
	// unless polymorphism is turned off
	protected def Pair<String, String> findCalledMethodType(JvmOperation operation, String actualTypeName,
		boolean polymorphic) {
		val relevantClassFqn = if (polymorphic) actualTypeName else operation.declaringType.qualifiedName
		if (classManager.canInterpretClass(relevantClassFqn)) {
			val type = classManager.getClassForName(actualTypeName)
			if (type.hasMethod(operation)) {
				return relevantClassFqn -> type.name
			} else {
				if (type.extendedClass != null) {
					return findCalledMethodType(operation, type.extendedClass)
				} else {
					return null
				}
			}
		} else {
			return null
		}
	}
	
	protected def JvmDeclaredType getExtendedClass(XtendTypeDeclaration type){
		if (type instanceof XtendClass){
			type.extends?.type as JvmDeclaredType ?: jvmTypes.findDeclaredType(Object, type) as JvmDeclaredType
		}else if (type instanceof AnonymousClass){
			val supertype = type.constructorCall?.constructor?.declaringType
			return supertype ?: jvmTypes.findDeclaredType(Object, type) as JvmDeclaredType
		}else {
			jvmTypes.findDeclaredType(Object, type) as JvmDeclaredType
		}
	}

	protected def Pair<String, String> findCalledMethodType(JvmOperation operation, JvmDeclaredType type) {
		if (type.hasMethod(operation)) {
			return type.qualifiedName -> type.simpleName
		} else {
			findCalledMethodType(operation, type.extendedClass.type as JvmDeclaredType)
		}
	}

	// handles dispatch functions, NOT polymorphism
	// the class given to this function must already be the correct one
	def protected XtendFunction getCalledFunction(
		XtendTypeDeclaration type,
		String op,
		int nArgs,
		List<Object> args	) {
		val candidates = type.members.filter(typeof(XtendFunction)).filter[name == op && parameters.size == nArgs]
		if (candidates.empty) {
			null
		} else if (candidates.findFirst[dispatch] != null) {

			// this is a set of dispatch functions, select candidate based on type of first argument
			if (args.empty) {
				throw new RuntimeException("Dispatch function '" + op + "' without parameters, shouldn't occur!")
			} else {
				val sortedCandidates = candidates.sort [ f1, f2 |
					compareFunctions(f1, f2)
				]
				for (func : sortedCandidates.filter[dispatch]) {
					if ((0 ..< nArgs).forall[i|
						objectRep.isInstanceOf(args.get(i), func.parameters.get(i).parameterType.type.qualifiedName)])
						return func
				}
				null
			}
		} else {
			if (candidates.size > 1) {
				println(
					"Choosing function call '" + op + "' among " + candidates.size + " candidates. " +
						"This choice might be wrong."
				)
			}
			candidates.get(0)
		}
	}

	def protected evaluateConstructor(XtendConstructor constr, IEvaluationContext context, CancelIndicator indicator) {
		val currentTypeBefore = currentType
		val result = doEvaluate(constr.expression, context, indicator)
		currentType = currentTypeBefore
	}

	def protected evaluateOperation(XtendFunction func, List<Object> argumentValues, XtendTypeDeclaration type,
		IEvaluationContext context, CancelIndicator indicator) {
		val receiver = context.getValue(QualifiedName.create("this"))
		for (var i = 0; i < argumentValues.size; i++) {
			val paramName = func.parameters.get(i).name
			val qname = QualifiedName.create(paramName)
			context.newValue(qname, argumentValues.get(i))
		}
		if (func.createExtensionInfo != null) {

			//val functionCache = receiver.getCreateCache(func) 
			if (objectRep.hasCreateMethodResult(receiver, func, argumentValues)) {
				return objectRep.getCreateMethodResult(receiver, func, argumentValues)
			} else {
				val created = doEvaluate(func.createExtensionInfo.createExpression, context, indicator)
				objectRep.setCreateMethodResult(receiver, func, argumentValues, created)
				val varName = func.createExtensionInfo.name
				context.newValue(QualifiedName.create(varName), created)
			}
		}
		try {
			val currentTypeBefore = currentType
			if (type != null)
				currentType = type
			var result = doEvaluate(func.expression, context, indicator)
			if (func.createExtensionInfo != null)
				result = objectRep.getCreateMethodResult(receiver, func, argumentValues)
			if (type != null)
				currentType = currentTypeBefore
			return result
		} catch (RuntimeException r) {
			if (r.class.simpleName == "ReturnValue") {
				val rvField = r.class.getDeclaredField("returnValue")
				rvField.accessible = true
				return rvField.get(r)

			// class Returnvalue is not visible from here apparently
			} else {
				throw r
			}
		}
	}

	protected override _invokeFeature(JvmField jvmField, XAbstractFeatureCall featureCall, Object receiver,
		IEvaluationContext context, CancelIndicator indicator) {
		val calledType = jvmField.declaringType.qualifiedName
		if (jvmField.static)
			return objectRep.getStaticFieldValue(jvmField)

			
		//TODO: should do subtype comparison
		//TODO: is this the place to look for this_0, this_1 features etc?
		if (currentType != null) {
			val currentTypeName = currentType.qualifiedName
			if (currentTypeName == calledType && receiver == null) {
				val currentInstance = context.getValue(QualifiedName.create("this"))
				val fieldName = featureCall.feature.simpleName
				if (currentInstance != null) {
					if (fieldName == "this")
						return currentInstance
					return objectRep.getFieldValue(currentInstance, jvmField)
				}
			}
		}

		return objectRep.getFieldValue(receiver, jvmField)

	//super._invokeFeature(jvmField, featureCall, receiver, context, indicator)
	}

	protected override _assigneValueTo(JvmField jvmField, XAbstractFeatureCall assignment, Object value,
		IEvaluationContext context, CancelIndicator indicator) {

		if (jvmField.static) {
			objectRep.setStaticFieldValue(jvmField, value)
			return value
		}

		val receiver = getReceiver(assignment, context, indicator)

		if (receiver != null) {
			objectRep.setFieldValue(receiver, jvmField, value)
			return value
		} else {			
			
			if (currentType != null) {
				val calledTypeFqn = jvmField.declaringType.qualifiedName
				val currentTypeName = currentType.qualifiedName
				
				val calledJvmType = jvmTypes.findDeclaredType(calledTypeFqn, currentType) as JvmDeclaredType
				val currentJvmType = if (currentType instanceof AnonymousClass)
					currentType.constructorCall.constructor.declaringType.superTypes.head.type as JvmDeclaredType
				else
					jvmTypes.findDeclaredType(currentTypeName, currentType) as JvmDeclaredType
				if (currentJvmType.isSubtypeOf(calledJvmType)) {
					val currentInstance = context.getValue(QualifiedName.create("this"))
					val fieldName = assignment.feature.simpleName
					if (currentInstance != null) {
						objectRep.setFieldValue(currentInstance, jvmField, value)
						return value
					}
				}
			}
		}

	//TODO: this is bad, which is the instance and which is the actual value? 
	// it also doesnt check if we assign something to a different instance of the same class
	// and of course the call at the end shouldn't be there any more probably.
	//		val calledType = jvmField.declaringType.qualifiedName
	//		if (currentType != null) {
	//			val currentTypeName = currentType.qualifiedName
	//			if (currentTypeName == calledType) {
	//				val currentInstance = context.getValue(QualifiedName.create("this"))
	//				val fieldName = assignment.feature.simpleName
	//				if (currentInstance != null) {
	//					objectRep.setFieldValue(currentInstance, fieldName, value)
	//					return value
	//				}
	//			}
	//		}
	//		super._assigneValueTo(jvmField, assignment, value, context, indicator)
	}
	
	//TODO: this only cares about extended classes, not interfaces; is that okay?
	def protected boolean isSubtypeOf(XtendClass clazz, JvmGenericType superType){
		if (clazz.qualifiedName == superType.qualifiedName)
			return true
		var superClazz = clazz.extends.type
		while (superClazz != null){
			if (superClazz == superType){
				return true
			}else{
				superClazz = (superClazz as JvmGenericType).extendedClass?.type
			}
		}
		false
	}

	override protected Object _invokeFeature(JvmIdentifiableElement identifiable, XAbstractFeatureCall featureCall,
		Object receiver, IEvaluationContext context, CancelIndicator indicator) {
//		if (featureCall.toString == "this" && currentType != null && identifiable instanceof JvmGenericType &&
//			identifiable.simpleName == currentType.name) {
		if (currentType != null && currentType instanceof XtendClass && identifiable instanceof JvmGenericType && (currentType as XtendClass).isSubtypeOf(identifiable as JvmGenericType)){
			val result = context.getValue(QualifiedName.create("this"))
			if (result != null)
				return result
		}
		var counter = 0
		while (context.getValue(QualifiedName.create("this_" + counter)) !== null){
			val referencedObject = context.getValue(QualifiedName.create("this_" + counter))
			val type = objectRep.getQualifiedClassName(referencedObject)
			val typeDecl = classManager.getClassForName(type)
			if (typeDecl instanceof XtendClass && identifiable instanceof JvmGenericType && (typeDecl as XtendClass).isSubtypeOf(identifiable as JvmGenericType)){
				return referencedObject
			}else{
				counter++
			}
		}
		super._invokeFeature(identifiable, featureCall, receiver, context, indicator)
	}

	//TODO: why do i override this again?
	override protected Object _doEvaluate(XClosure closure, IEvaluationContext context, CancelIndicator indicator) {
		var Class<?> functionIntf = null;
		switch (closure.getFormalParameters().size()) {
			case 0:
				functionIntf = getClass(Functions.Function0)
			case 1:
				functionIntf = getClass(Functions.Function1)
			case 2:
				functionIntf = getClass(Functions.Function2)
			case 3:
				functionIntf = getClass(Functions.Function3)
			case 4:
				functionIntf = getClass(Functions.Function4)
			case 5:
				functionIntf = getClass(Functions.Function5)
			case 6:
				functionIntf = getClass(Functions.Function6)
			default:
				throw new IllegalStateException("Closures with more than 6 parameters are not supported.")
		}
		val invocationHandler = new XtendClosureInvocationHandler(closure, context, this, indicator);
		val proxy = Proxy.newProxyInstance(usedClassLoader, #[functionIntf], invocationHandler);
		return proxy;
	}

	override protected _doEvaluate(XAbstractFeatureCall featureCall, IEvaluationContext context,
		CancelIndicator indicator) {
		var Object before = null
		if (featureCall.feature instanceof JvmExecutable) {
			if (!currentStackTrace.empty())
				before = currentStackTrace.peek
			currentStackTrace.push(featureCall)
		}
		val result = super._doEvaluate(featureCall, context, indicator)
		if (featureCall.feature instanceof JvmExecutable) {
			currentStackTrace.pop

			// maybe something bad happened in the meantime? like a thrown and caught exception?
			// in which case there may be other stuff on the stack now? and we should remove it
			while (!currentStackTrace.empty() && before != null && currentStackTrace.peek != before) {
				currentStackTrace.pop
			}
		}
		return result
	}

	override protected _doEvaluate(XMemberFeatureCall featureCall, IEvaluationContext context, CancelIndicator indicator) {
		if (featureCall.feature instanceof JvmExecutable) {
			currentStackTrace.push(featureCall)
		}
		val result = super._doEvaluate(featureCall, context, indicator)
		if (featureCall.feature instanceof JvmExecutable) {
			currentStackTrace.pop
		}
		return result
	}
}
