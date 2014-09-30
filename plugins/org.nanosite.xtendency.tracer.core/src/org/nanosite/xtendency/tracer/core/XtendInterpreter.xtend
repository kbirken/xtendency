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

@Data class XtendClassResource {
	IFile file
	URI uri
}

class XtendInterpreter extends XbaseInterpreter {

	@Inject
	protected RichStringProcessor richStringProcessor

	@Inject
	protected IResourceSetProvider rsProvider

	@Inject
	protected Provider<DefaultIndentationHandler> indentationHandler

	protected BiMap<IFile, URI> usedClasses = HashBiMap.create
	protected Map<String, Pair<IFile, URI>> availableClasses = new HashMap<String, Pair<IFile, URI>>
	protected IContainer baseDir

	XtendTypeDeclaration currentType

	protected ClassLoader injectedClassLoader

	private ResourceSet rs
	
	def getUsedClasses(){
		return usedClasses
	}

	def configure(IContainer container) {
		this.rs = rsProvider.get(container.project)
		this.baseDir = container
		for (f : container.members.filter(IFile).filter[name.endsWith(".xtend")]) {
			val uri = URI.createURI(f.fullPath.toString, true)
			try {
				val r = rs.getResource(uri, true)
				val file = r.contents.head
				if (file instanceof XtendFile) {
					for (type : file.xtendTypes) {
						val name = file.package + "." + type.name
						availableClasses.put(name, f -> uri)
					}
				}
			} catch (Exception e) {
				// ignore
			}
		}
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
			println("injected class loader is " + injectedClassLoader)
			val classPathEntries = JavaRuntime.computeDefaultRuntimeClassPath(jp)
			val classPathUrls = classPathEntries.map[new Path(it).toFile().toURI().toURL()]

			var ClassLoader parent = injectedClassLoader
			parent = new DelegatorClassLoader(parent, FrameworkUtil.getBundle(XtendInterpreter).getBundleContext(),
				classPathUrls.map[toString])

			val result = new URLClassLoader(classPathUrls, parent)
			super.classLoader = result
			return result
		}
		null
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
		val calledType = operation.declaringType.qualifiedName
		val firstArg = if (argumentValues.empty) null else argumentValues.get(0)
		val op = operation.simpleName
		if (currentType != null) {
			val currentTypeName = (currentType.eContainer as XtendFile).package + "." + currentType.name
			if (currentTypeName == calledType && receiver == null) {
				val calledFunc = getCalledFunction(currentType, op, argumentValues.size, firstArg)
				println("interpreting function 1 " + calledFunc.name)
				val newContext = context.fork
				return evaluateOperation(calledFunc, argumentValues, null, newContext, indicator)
			}
		} 
		if (availableClasses.containsKey(calledType)) {
			val locationInfo = availableClasses.get(calledType)
			val resource = rs.getResource(locationInfo.value, true)
			val type = (resource.contents.head as XtendFile).xtendTypes.findFirst[
				name == operation.declaringType.simpleName]
			val calledFunc = getCalledFunction(type, op, argumentValues.size, firstArg)
			println("interpreting function 2 " + calledFunc.name)
			usedClasses.put(locationInfo.key, locationInfo.value)
			val newContext = context.fork
			newContext.newValue(QualifiedName.create("this"), receiver)
			return evaluateOperation(calledFunc, argumentValues, type, newContext, indicator)
		}
		super.invokeOperation(operation, receiver, argumentValues, context, indicator)
	}

	def private XtendFunction getCalledFunction(
		XtendTypeDeclaration type,
		String op,
		int nArgs,
		/*@Nullable*/ Object firstArg
	) {
		val candidates = type.members.filter(typeof(XtendFunction)).filter[name==op && parameters.size==nArgs]
		if (candidates.empty) {
			null
		} else if (candidates.findFirst[dispatch]!=null) {
			// this is a set of dispatch functions, select candidate based on type of first argument
			if (firstArg==null) {
				throw new RuntimeException("Dispatch function '" + op + "' without parameters, shouldn't occur!")
			} else {
				for(func : candidates.filter[dispatch]) {
					val tFQN = func.parameters.get(0).parameterType.type.qualifiedName
					if (isInstanceOf(firstArg, tFQN)) {
						return func
					}
				}
				null
			}
		} else {
			if (candidates.size > 1) {
				println("Choosing function call '" + op + "' among " + candidates.size + " candidates. " +
					"This choice might be wrong."
				)
			}
			candidates.get(0)
		}
	}

	def private isInstanceOf (Object obj, String typeFQN) {
		var Class<?> expectedType = null
		val className = typeFQN
		try {
			expectedType = classFinder.forName(className)
		} catch (ClassNotFoundException cnfe) {
			throw new EvaluationException(new NoClassDefFoundError(className))
		}
		expectedType.isInstance(obj)
	}

	
	def private evaluateOperation(
		XtendFunction func,
		List<Object> argumentValues,
		XtendTypeDeclaration type,
		IEvaluationContext context,
		CancelIndicator indicator
	) {
			for (var i = 0; i < argumentValues.size; i++) {
				val paramName = func.parameters.get(i).name
			context.newValue(QualifiedName.create(paramName), argumentValues.get(i))
			}
			try {
				val currentTypeBefore = currentType
			if (type!=null)
				currentType = type
			val result = doEvaluate(func.expression, context, indicator)
			if (type!=null)
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
	
	override Object _invokeFeature(JvmIdentifiableElement identifiable, XAbstractFeatureCall featureCall, Object receiver,
			IEvaluationContext context, CancelIndicator indicator) {
		if (featureCall.toString =="this" && currentType != null && identifiable instanceof JvmGenericType && identifiable.simpleName == currentType.name){
			val result = context.getValue(QualifiedName.create("this"))
			if (result != null)
				return result
		}
		super._invokeFeature(identifiable, featureCall, receiver, context, indicator)
	}
	
}
