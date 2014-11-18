package org.nanosite.xtendency.tracer.core

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.List
import org.eclipse.xtend.core.richstring.DefaultIndentationHandler
import org.eclipse.xtend.core.richstring.RichStringProcessor
import org.eclipse.xtend.core.xtend.RichString
import org.eclipse.xtend.core.xtend.RichStringForLoop
import org.eclipse.xtend.core.xtend.RichStringIf
import org.eclipse.xtend.core.xtend.RichStringLiteral
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter
import org.eclipse.xtend.core.richstring.IRichStringPartAcceptor
import org.eclipse.xtext.xbase.interpreter.IExpressionInterpreter
import org.eclipse.xtext.common.types.JvmField
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import org.eclipse.core.resources.IProject
import org.eclipse.osgi.internal.loader.EquinoxClassLoader
import org.eclipse.jdt.core.IJavaProject
import org.eclipse.core.runtime.Path
import java.net.URLClassLoader
import org.eclipse.jdt.launching.JavaRuntime
import org.osgi.framework.FrameworkUtil
import org.eclipse.core.resources.IFile
import org.eclipse.emf.common.util.URI
import java.util.ArrayList
import org.eclipse.core.resources.IContainer
import java.util.Map
import java.util.HashMap
import org.eclipse.xtext.ui.resource.IResourceSetProvider
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.common.types.JvmIdentifiableElement
import org.eclipse.xtext.common.types.JvmGenericType
import com.google.common.collect.BiMap
import com.google.common.collect.HashBiMap
import org.eclipse.xtext.xbase.interpreter.impl.EvaluationException
import java.util.IdentityHashMap
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtext.common.types.JvmDeclaredType
import org.eclipse.xtext.xbase.typesystem.IBatchTypeResolver

@Data class XtendClassResource {
	IFile file
	URI uri
}

class XtendInterpreter extends XbaseInterpreter {
	
	@Inject 
	protected IBatchTypeResolver typeResolver

	@Inject
	protected RichStringProcessor richStringProcessor

	@Inject
	protected Provider<DefaultIndentationHandler> indentationHandler

	// TODO: remove IFile here, push to WorkspaceXtendInterpreter
	protected BiMap<IFile, URI> usedClasses = HashBiMap.create
	protected Map<String, Pair<IFile, URI>> availableClasses = new HashMap<String, Pair<IFile, URI>>
	protected Map<Pair<XtendFunction, Object>, Map<List<?>, Object>> createCache = new HashMap<Pair<XtendFunction, Object>, Map<List<?>, Object>>
	
	IExtendedEvaluationContext globalScope

	XtendTypeDeclaration currentType

	protected ClassLoader injectedClassLoader

	protected ResourceSet rs

	def getUsedClasses() {
		return usedClasses
	}

	def setCurrentType(XtendTypeDeclaration thisType, IFile file) {
		this.currentType = thisType
		usedClasses.put(file, thisType.eResource.URI)
	}

	def setCurrentType(XtendTypeDeclaration thisType) {
		this.currentType = thisType
	}

	override void setClassLoader(ClassLoader cl) {
		if (cl instanceof EquinoxClassLoader)
			this.injectedClassLoader = cl
		super.classLoader = cl
	}

	def ClassLoader addProjectToClasspath(IJavaProject jp) {
		if (injectedClassLoader != null) {
			val classPathEntries = JavaRuntime.computeDefaultRuntimeClassPath(jp)
			val classPathUrls = classPathEntries.map[new Path(it).toFile().toURI().toURL()]

			var ClassLoader parent = injectedClassLoader
			parent = new DelegatorClassLoader(parent, XtendInterpreter,
				classPathUrls.map[toString])

			val result = new URLClassLoader(classPathUrls, parent)
			super.classLoader = result
			return result
		}
		null
	}
	
	def setGlobalScope(IExtendedEvaluationContext context){
		globalScope = context
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
		} else {
			super.doEvaluate(expression, context, indicator)
		}
	}

	protected override Object invokeOperation(JvmOperation operation, Object receiver, List<Object> argumentValues,
		IEvaluationContext context, CancelIndicator indicator) {
		// to do polymorphism properly
		// find out which class the object actually has
		// then iterate through types
		var String calledTypeFqn = null
		var String calledTypeSimpleNonFinal = null
		if (receiver != null){
			val calledType = findCalledMethodType(operation, receiver.class.canonicalName, receiver.class.simpleName)
			//calledtype may be null if the class is not available in xtend
			if (calledType == null)
				return super.invokeOperation(operation, receiver, argumentValues, context, indicator)
			
			calledTypeFqn = calledType.key
			calledTypeSimpleNonFinal = calledType.value
		}else{
			calledTypeFqn = operation.declaringType.qualifiedName 
			calledTypeSimpleNonFinal = operation.declaringType.simpleName
		}
		val calledTypeSimple = calledTypeSimpleNonFinal
		val op = operation.simpleName
		if (currentType != null) {
			val currentTypeName = (currentType.eContainer as XtendFile).package + "." + currentType.name
			if (currentTypeName == calledTypeFqn && receiver == null) {
				val calledFunc = getCalledFunction(currentType, op, argumentValues.size, argumentValues)

				val newContext = globalScope.fork
				newContext.newValue(QualifiedName.create("this"), context.getValue(QualifiedName.create("this")))
				return evaluateOperation(calledFunc, argumentValues, null, newContext, indicator)
			}
		}
		if (availableClasses.containsKey(calledTypeFqn)) {
			val locationInfo = availableClasses.get(calledTypeFqn)
			val resource = rs.getResource(locationInfo.value, true)
			val type = (resource.contents.head as XtendFile).xtendTypes.findFirst[
				name == calledTypeSimple]
			val calledFunc = getCalledFunction(type, op, argumentValues.size, argumentValues)

			usedClasses.put(locationInfo.key, locationInfo.value)
			val newContext = globalScope.fork
			newContext.newValue(QualifiedName.create("this"), receiver)
			return evaluateOperation(calledFunc, argumentValues, type, newContext, indicator)
		}
		super.invokeOperation(operation, receiver, argumentValues, context, indicator)
	}
	
	// given an operation and the actual runtime type of an object, returns the FQN of the class which first implements it
	protected def Pair<String, String> findCalledMethodType(JvmOperation operation, String actualTypeName, String actualTypeSimpleName){
		if (availableClasses.containsKey(actualTypeName)){
			val locationInfo = availableClasses.get(actualTypeName)
			val resource = rs.getResource(locationInfo.value, true)
			val type = (resource.contents.head as XtendFile).xtendTypes.filter(XtendClass).findFirst[
				name == actualTypeSimpleName]
			if (type.hasMethod(operation)){
				return actualTypeName -> actualTypeSimpleName
			}else{
				if (type.extends.type instanceof JvmDeclaredType){
					return findCalledMethodType(operation, type.extends.type as JvmDeclaredType)
				}
			}
		}else{
			return null
		}
	}
	
	protected def Pair<String, String> findCalledMethodType(JvmOperation operation, JvmDeclaredType type){
		if (type.hasMethod(operation)){
			return type.qualifiedName -> type.simpleName
		}else{
			findCalledMethodType(operation, type.extendedClass.type as JvmDeclaredType)
		}
	}
	
	protected def boolean hasMethod(JvmDeclaredType type, JvmOperation op){
		type.declaredOperations.exists[operationsEqual(it, op)]
	}
	
	protected def boolean hasMethod(XtendClass type, JvmOperation op){
		type.members.filter(XtendFunction).exists[operationsEqual(it, op)]
	}
	
	protected def boolean operationsEqual(XtendFunction op1, JvmOperation op2){
		if (op1.name != op2.simpleName)
			return false
		if (op1.parameters.size != op2.parameters.size)
			return false
//		if (op1.returnType != op2.returnType)
//			return false
		for (i : 0..<op1.parameters.size){
			val p1 = op1.parameters.get(i)
			val p2 = op2.parameters.get(i)
			if (p1.parameterType.qualifiedName != p2.parameterType.qualifiedName)
				return false
		}
		return true
	}
	
	protected def boolean operationsEqual(JvmOperation op1, JvmOperation op2){
		if (op1.simpleName != op2.simpleName)
			return false
		if (op1.parameters.size != op2.parameters.size)
			return false
		if (op1.returnType != op2.returnType)
			return false
		for (i : 0..<op1.parameters.size){
			val p1 = op1.parameters.get(i)
			val p2 = op2.parameters.get(i)
			if (p1.parameterType.qualifiedName != p2.parameterType.qualifiedName)
				return false
		}
		return true
	}

	def protected XtendFunction getCalledFunction(
		XtendTypeDeclaration type,
		String op,
		int nArgs,
		List<Object> args
	) {
		val candidates = type.members.filter(typeof(XtendFunction)).filter[name == op && parameters.size == nArgs]
		if (candidates.empty) {
			null
		} else if (candidates.findFirst[dispatch] != null) {

			// this is a set of dispatch functions, select candidate based on type of first argument
			if (args.empty) {
				throw new RuntimeException("Dispatch function '" + op + "' without parameters, shouldn't occur!")
			} else {
				val sortedCandidates = candidates.sort[f1, f2 | 
					compareFunctions(f1, f2)
				]
				for (func : sortedCandidates.filter[dispatch]) {
					if ((0..<nArgs).forall[i | isInstanceOf(args.get(i), func.parameters.get(i).parameterType.type.qualifiedName)])
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
	
	def int compareFunctions(XtendFunction f1, XtendFunction f2){
		for (i : 0..<f1.parameters.size){
			val currentParam = f1.parameters.get(i).parameterType.compareTypes(f2.parameters.get(i).parameterType)
			if (currentParam != 0)
				return currentParam
		}
		throw new IllegalArgumentException
	}
	
	def int compareTypes(JvmTypeReference t1, JvmTypeReference t2){
		val t1Type = classFinder.forName(t1.type.qualifiedName)
		val t2Type = classFinder.forName(t2.type.qualifiedName)
		val t2get1 = t2Type.isAssignableFrom(t1Type)
		val t1get2 = t1Type.isAssignableFrom(t2Type)
		if (t2get1){
			if (t1get2){
				throw new IllegalArgumentException
			}else{
				-1
			}
		}else if (t1get2){
			1
		}else{
			0
		}
	}

	def protected isInstanceOf(Object obj, String typeFQN) {
		var Class<?> expectedType = null
		val className = typeFQN
		try {
			expectedType = classFinder.forName(className)
		} catch (ClassNotFoundException cnfe) {
			throw new EvaluationException(new NoClassDefFoundError(className))
		}
		expectedType.isInstance(obj)
	}
	
	def protected Map<List<?>, Object> safeGet(Map<Pair<XtendFunction, Object>, Map<List<?>, Object>> map, Pair<XtendFunction, Object> k){
		if (map.containsKey(k)){
			return map.get(k)
		}else{
			val result = new HashMap<List<?>, Object>
			map.put(k, result)
			result
		}
	}

	def protected evaluateOperation(XtendFunction func, List<Object> argumentValues, XtendTypeDeclaration type,
		IEvaluationContext context, CancelIndicator indicator) {
		val receiver = context.getValue(QualifiedName.create("this"))
		for (var i = 0; i < argumentValues.size; i++) {
			val paramName = func.parameters.get(i).name
			val qname = QualifiedName.create(paramName)
			context.newValue(qname, argumentValues.get(i))
		}
		if (func.createExtensionInfo != null){
			val functionCache = createCache.safeGet(func -> receiver)
			if (functionCache.containsKey(argumentValues)){
				return functionCache.get(argumentValues)
			}else{
				val created = doEvaluate(func.createExtensionInfo.createExpression, context, indicator)
				functionCache.put(argumentValues, created)
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
				result = createCache.safeGet(func -> receiver).get(argumentValues)
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
		if (currentType != null) {
			val currentTypeName = (currentType.eContainer as XtendFile).package + "." + currentType.name
			if (currentTypeName == calledType && receiver == null) {
				val currentInstance = context.getValue(QualifiedName.create("this"))
				val fieldName = featureCall.feature.simpleName
				if (currentInstance != null) {
					if (fieldName == "this")
						return currentInstance
					val field = currentInstance.class.getDeclaredField(fieldName)
					field.accessible = true
					return field.get(currentInstance)
				}
			}
		}
		super._invokeFeature(jvmField, featureCall, receiver, context, indicator)
	}

	protected override _assigneValueTo(JvmField jvmField, XAbstractFeatureCall assignment, Object value,
		IEvaluationContext context, CancelIndicator indicator) {
		val calledType = jvmField.declaringType.qualifiedName
		if (currentType != null) {
			val currentTypeName = (currentType.eContainer as XtendFile).package + "." + currentType.name
			if (currentTypeName == calledType) {
				val currentInstance = context.getValue(QualifiedName.create("this"))
				val fieldName = assignment.feature.simpleName
				if (currentInstance != null) {
					try {
						val field = currentInstance.class.getDeclaredField(fieldName)
						field.accessible = true

						field.set(currentInstance, value)
						return value
					} catch (NoSuchFieldException e) {
						e.printStackTrace
					}
				}
			}
		}
		super._assigneValueTo(jvmField, assignment, value, context, indicator)
	}

	override Object _invokeFeature(JvmIdentifiableElement identifiable, XAbstractFeatureCall featureCall,
		Object receiver, IEvaluationContext context, CancelIndicator indicator) {
		if (featureCall.toString == "this" && currentType != null && identifiable instanceof JvmGenericType &&
			identifiable.simpleName == currentType.name) {
			val result = context.getValue(QualifiedName.create("this"))
			if (result != null)
				return result
		}
		super._invokeFeature(identifiable, featureCall, receiver, context, indicator)
	}

}
