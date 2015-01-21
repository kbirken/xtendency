package org.nanosite.xtendency.interpreter

import com.google.inject.Inject
import com.google.inject.Provider
import java.io.BufferedReader
import java.io.PrintWriter
import java.io.StringReader
import java.io.StringWriter
import java.lang.reflect.Proxy
import java.util.List
import java.util.Stack
import org.eclipse.osgi.internal.loader.EquinoxClassLoader
import org.eclipse.xtend.core.richstring.DefaultIndentationHandler
import org.eclipse.xtend.core.richstring.RichStringProcessor
import org.eclipse.xtend.core.xtend.AnonymousClass
import org.eclipse.xtend.core.xtend.RichString
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendConstructor
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.xtext.common.types.JvmConstructor
import org.eclipse.xtext.common.types.JvmDeclaredType
import org.eclipse.xtext.common.types.JvmExecutable
import org.eclipse.xtext.common.types.JvmField
import org.eclipse.xtext.common.types.JvmGenericType
import org.eclipse.xtext.common.types.JvmIdentifiableElement
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtext.common.types.JvmType
import org.eclipse.xtext.common.types.JvmVisibility
import org.eclipse.xtext.common.types.util.TypeReferences
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import org.eclipse.xtext.xbase.XClosure
import org.eclipse.xtext.xbase.XConstructorCall
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XMemberFeatureCall
import org.eclipse.xtext.xbase.XTypeLiteral
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationResult
import org.eclipse.xtext.xbase.interpreter.impl.EvaluationException
import org.eclipse.xtext.xbase.interpreter.impl.InterpreterCanceledException
import org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter
import org.eclipse.xtext.xbase.typesystem.IBatchTypeResolver

import static extension org.nanosite.xtendency.interpreter.InterpreterUtil.*
import org.eclipse.xtext.common.types.JvmTypeReference
import java.lang.reflect.InvocationHandler
import org.eclipse.xtext.xbase.interpreter.impl.DelegatingInvocationHandler
import org.eclipse.xtend.core.xtend.XtendEnum
import org.eclipse.xtext.xbase.XSwitchExpression
import org.eclipse.xtext.xbase.util.XSwitchExpressions
import org.eclipse.xtext.xbase.featurecalls.IdentifiableSimpleNameProvider

class XtendInterpreter extends XbaseInterpreter {
	
	@Inject
	private IdentifiableSimpleNameProvider featureNameProvider;
	
	@Inject
	private XSwitchExpressions switchExpressions;

	@Inject
	protected IBatchTypeResolver typeResolver

	@Inject
	protected RichStringProcessor richStringProcessor

	@Inject
	protected TypeReferences jvmTypes

	@Inject
	protected Provider<DefaultIndentationHandler> indentationHandler

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
	
	@Deprecated
	override evaluate(XExpression expression) {
		super.evaluate(expression)
	}
	
	def evaluate(XExpression expression, IClassManager classMgr) {
		evaluate(expression, new ChattyEvaluationContext, CancelIndicator.NullImpl, classMgr)
	}
	
	def evaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator, IClassManager classMgr){
		evaluate(expression, context, indicator, classMgr, [])
	}

	def protected evaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator, IClassManager classMgr, ()=>void afterInit){
		this.classManager = classMgr
		if (classMgr.configuredClassLoader == null)
			super.classLoader = classMgr.configureClassLoading(injectedClassLoader)
		else
			super.classLoader = classMgr.configuredClassLoader
		util = new InterpreterUtil(classFinder)

		currentStackTrace.clear
		val slf = this
		objectRep.init(javaReflectAccess, classFinder, classMgr, jvmTypes, new IInterpreterAccess(){
			
			override evaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator) {
				slf.internalEvaluate(expression, context, indicator)
			}
			
			override evaluateArgumentExpressions(JvmExecutable executable, List<XExpression> expressions, IEvaluationContext context, CancelIndicator indicator) {
				slf.evaluateArgumentExpressions(executable, expressions, context, indicator)
			}
			
			override invokeOperation(JvmOperation operation, Object receiver, List<Object> argumentValues, IEvaluationContext context, CancelIndicator indicator) {
				slf.invokeOperation(operation, receiver, argumentValues, context, indicator)
			}
			
		})
		afterInit.apply

		calledCorrectly = true
		val result = evaluate(expression, context, CancelIndicator.NullImpl)
		calledCorrectly = false
		result
	}

	@Deprecated
	/**
	 * Do not use this method, it won't work. It only exists as a leftover from XbaseInterpreter.
	 */
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

	/**
	 * Use this method to invoke a static method.
	 */
	def evaluateMethod(XtendFunction method, IClassManager classMgr, List<? extends Object> arguments){
		evaluateMethod(method, null, classMgr, arguments)
	}
	
	/**
	 * It is not recommended to invoke non-static methods on an existing instance, unless
	 * this instance was returned by a previous invocation of the interpreter. 
	 * 
	 * Undefined behavior may occur otherwise.
	 */
	def evaluateMethod(XtendFunction method, Object currentInstance, IClassManager classMgr,
		List<? extends Object> arguments) {
		if (method.static && currentInstance != null)
			throw new IllegalArgumentException
		if (!method.static && currentInstance == null)
			throw new IllegalArgumentException
		if (method.parameters.size != arguments.size)
			throw new IllegalArgumentException

		val clazz = method.declaringType as XtendClass

		classMgr.recordClassUse(clazz.qualifiedName)

		val context = new ChattyEvaluationContext
		if (currentInstance != null)
			context.newValue(QualifiedName.create("this"), currentInstance)
		for (i : 0 ..< method.parameters.size) {
			context.newValue(QualifiedName.create(method.parameters.get(i).name), arguments.get(i))
		}

		evaluate(method.expression, context, CancelIndicator.NullImpl, classMgr, [objectRep.initializeClass(clazz)])
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
		} else if (expression instanceof AnonymousClass) {
			_doEvaluate(expression, context, indicator)
		} else {
			super.doEvaluate(expression, context, indicator)
		}
	}

	override protected translateJvmTypeToResult(JvmType type, int arrayDims) {
		objectRep.getClass(type, arrayDims)
	}

	def Object _doEvaluate(AnonymousClass expression, IEvaluationContext context, CancelIndicator indicator) {
		objectRep.executeAnonymousClassConstructor(expression,
			evaluateArgumentExpressions(expression.constructorCall.constructor, expression.constructorCall.arguments,
				context, indicator), context)
	}

	override protected evaluateArgumentExpressions(JvmExecutable executable, List<XExpression> expressions,
		IEvaluationContext context, CancelIndicator indicator) {
		super.evaluateArgumentExpressions(executable, expressions, context, indicator)
	}
	
	override protected internalEvaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator) throws EvaluationException {
		super.internalEvaluate(expression, context, indicator)
	}

	override protected _doEvaluate(XConstructorCall constructorCall, IEvaluationContext context,
		CancelIndicator indicator) {
		val jvmConstructor = constructorCall.getConstructor
		val arguments = evaluateArgumentExpressions(jvmConstructor, constructorCall.getArguments(), context, indicator)

		return objectRep.executeConstructorCall(constructorCall, jvmConstructor, arguments)
	}
	
	// overridden only to prevent direct classFinder access
	//TODO: maybe instead of overriding this (and possibly others?), build a classFinder that uses the ORS
	//and reflection-put it into the XbaseInterpreter field
	//because this sucks
	protected override  Object _doEvaluate(XSwitchExpression switchExpression, IEvaluationContext context, CancelIndicator indicator) {
		val forkedContext = context.fork();
		val conditionResult = internalEvaluate(switchExpression.getSwitch(), forkedContext, indicator);
		val simpleName = featureNameProvider.getSimpleName(switchExpression.getDeclaredParam());
		if (simpleName != null) {
			forkedContext.newValue(QualifiedName.create(simpleName), conditionResult);
		}
		for (casePart : switchExpression.getCases()) {
			var Class<?> expectedType = null;
			if (casePart.getTypeGuard() != null) {
				val typeName = casePart.getTypeGuard().getType().getQualifiedName();
				try {
					// only change, replaces classFinder.forName(typeName)
					expectedType = objectRep.getClass(jvmTypes.findDeclaredType(typeName, switchExpression), 0)
				} catch (ClassNotFoundException e) {
					throw new EvaluationException(new NoClassDefFoundError(typeName));
				}
			}
			if (expectedType != null && switchExpression.getSwitch() == null)
				throw new IllegalStateException("Switch without expression or implicit 'this' may not use type guards");
			if (expectedType == null || expectedType.isInstance(conditionResult)) {
				if (casePart.getCase() != null) {
					val casePartResult = internalEvaluate(casePart.getCase(), forkedContext, indicator);
					if (Boolean.TRUE.equals(casePartResult) || eq(conditionResult, casePartResult)) {
						val then = switchExpressions.getThen(casePart, switchExpression);
						return internalEvaluate(then, forkedContext, indicator);
					}
				} else {
					val then = switchExpressions.getThen(casePart, switchExpression);
					return internalEvaluate(then, forkedContext, indicator);
				}
			}
		}
		if (switchExpression.getDefault() != null) {
			val defaultResult = internalEvaluate(switchExpression.getDefault(), forkedContext, indicator);
			return defaultResult;
		}
		return getDefaultObjectValue(typeResolver.resolveTypes(switchExpression).getActualType(switchExpression));
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

	protected override Object invokeOperation(JvmOperation operation, Object receiver, List<Object> argumentValues,
		IEvaluationContext context, CancelIndicator indicator) {
		invokeOperation(operation, receiver, argumentValues, context, indicator,
			if(operation.visibility == JvmVisibility.PRIVATE) false else true)
	}

	override protected _invokeFeature(JvmOperation operation, XAbstractFeatureCall featureCall, Object receiver,
		IEvaluationContext context, CancelIndicator indicator) {
		val operationArguments = getActualArguments(featureCall);
		val argumentValues = evaluateArgumentExpressions(operation, operationArguments, context, indicator);
		val polymorphic = if(operation.visibility == JvmVisibility.PRIVATE ||
				featureCall.actualReceiver?.toString == "super") false else true
		return invokeOperation(operation, receiver, argumentValues, context, indicator, polymorphic);
	}

	override protected getJavaType(JvmType type) throws ClassNotFoundException {
		objectRep.getClass(type, 0)
	}

	protected def Object invokeOperation(JvmOperation operation, Object receiver, List<Object> argumentValues,
		IEvaluationContext context, CancelIndicator indicator, boolean polymorphicInvoke) {

		// to do polymorphism properly
		// find out which class the object actually has
		// then iterate through types
		var String calledTypeFqn = null
		var String calledTypeSimpleNonFinal = null

		if (receiver !== null) {

			val calledType = findCalledMethodType(operation, objectRep.getQualifiedClassName(receiver),
				polymorphicInvoke)

			//calledtype may be null if the class is not available in xtend
			if (calledType == null) {
				if (!polymorphicInvoke) {
					val method = objectRep.getJavaOnlyMethod(receiver, operation)
					method.accessible = true
					return method.invoke(receiver, argumentValues.toArray)
				} else {
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
		if (!polymorphicInvoke) {
			val method = objectRep.getJavaOnlyMethod(receiver, operation)
			method.accessible = true
			return method.invoke(receiver, argumentValues)
		} else {
			return super.invokeOperation(operation, receiver, argumentValues, context, indicator)
		}

	}

	// given an operation and the actual runtime type of an object, returns the FQN of the class which first implements it
	// i.e. does polymorphism
	// unless polymorphism is turned off
	protected def Pair<String, String> findCalledMethodType(JvmOperation operation, String actualTypeName,
		boolean polymorphic) {
		val relevantClassFqn = if(polymorphic) actualTypeName else operation.declaringType.qualifiedName
		if (classManager.canInterpretClass(relevantClassFqn)) {
			val type = classManager.getClassForName(relevantClassFqn)
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

	protected def JvmDeclaredType getExtendedClass(XtendTypeDeclaration type) {
		if (type instanceof XtendClass) {
			type.extends?.type as JvmDeclaredType ?: jvmTypes.findDeclaredType(Object, type) as JvmDeclaredType
		} else if (type instanceof AnonymousClass) {
			val supertype = type.constructorCall?.constructor?.declaringType
			return supertype ?: jvmTypes.findDeclaredType(Object, type) as JvmDeclaredType
		} else {
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
	def protected XtendFunction getCalledFunction(XtendTypeDeclaration type, String op, int nArgs, List<Object> args) {
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

		//TODO: do we need this method
		val result = doEvaluate(constr.expression, context, indicator)
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
			var result = doEvaluate(func.expression, context, indicator)
			if (func.createExtensionInfo != null)
				result = objectRep.getCreateMethodResult(receiver, func, argumentValues)
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

		val instance = context.getValue(QualifiedName.create("this"))

		if (instance !== null) {
			val currentTypeName = objectRep.getQualifiedClassName(instance)
			if (receiver == null && currentTypeName.isSubtypeOf(jvmField.declaringType)) {
				val fieldName = featureCall.feature.simpleName
				if (fieldName == "this")
					return instance
				return objectRep.getFieldValue(instance, jvmField)
			}
		}

		return objectRep.getFieldValue(receiver, jvmField)

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
			val instance = context.getValue(QualifiedName.create("this"))
			val currentTypeName = objectRep.getQualifiedClassName(instance)
			if (receiver == null && currentTypeName.isSubtypeOf(jvmField.declaringType)) {
				objectRep.setFieldValue(instance, jvmField, value)
				return value
			} else {
				throw new NullPointerException
			}
		}
	}

	//TODO: this only cares about extended classes, not interfaces; is that okay?
	def protected boolean isSubtypeOf(XtendClass clazz, JvmGenericType superType) {
		if (clazz.qualifiedName == superType.qualifiedName)
			return true
		var superClazz = clazz.extends.type
		while (superClazz != null) {
			if (superClazz == superType) {
				return true
			} else {
				superClazz = (superClazz as JvmGenericType).extendedClass?.type
			}
		}
		false
	}

	override protected Object _invokeFeature(JvmIdentifiableElement identifiable, XAbstractFeatureCall featureCall,
		Object receiver, IEvaluationContext context, CancelIndicator indicator) {

		if (identifiable instanceof JvmDeclaredType) {
			val instance = context.getValue(QualifiedName.create("this"))

			if (instance !== null) {
				val currentTypeName = objectRep.getQualifiedClassName(instance)
				if (receiver == null && currentTypeName.isSubtypeOf(identifiable)) {
					return instance
				}
			}
		}

		var counter = 0
		while (context.getValue(QualifiedName.create("this_" + counter)) !== null) {
			val referencedObject = context.getValue(QualifiedName.create("this_" + counter))
			val type = objectRep.getQualifiedClassName(referencedObject)
			val typeDecl = classManager.getClassForName(type)
			if (typeDecl instanceof XtendClass && identifiable instanceof JvmGenericType &&
				(typeDecl as XtendClass).isSubtypeOf(identifiable as JvmGenericType)) {
				return referencedObject
			} else {
				counter++
			}
		}
		super._invokeFeature(identifiable, featureCall, receiver, context, indicator)
	}

	def protected boolean isSubtypeOf(String t1, JvmDeclaredType t2) {
		var jvmT1 = jvmTypes.findDeclaredType(t1, t2) as JvmDeclaredType
		if (jvmT1 === null) {
			val anonymous = classManager.getClassForName(t1) as AnonymousClass
			jvmT1 = anonymous.constructorCall.constructor.declaringType.superTypes.head.type as JvmDeclaredType
		}
		jvmT1.isSubtypeOf(t2)
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

	override protected _doEvaluate(XTypeLiteral literal, IEvaluationContext context, CancelIndicator indicator) {
		objectRep.getClass(literal.type, literal.arrayDimensions.size)
	}

	override protected coerceArgumentType(Object value, JvmTypeReference expectedType) {
		try {
			super.coerceArgumentType(value, expectedType)
		} catch (NoClassDefFoundError e) {

			//TODO: i have no idea if this is what we want
			return value
		}
	}

}
