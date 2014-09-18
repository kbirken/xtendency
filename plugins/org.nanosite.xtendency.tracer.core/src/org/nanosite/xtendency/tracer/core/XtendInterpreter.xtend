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

@Data class XtendClassResource {
	String classId
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

	protected List<XtendClassResource> usedClasses = new ArrayList<XtendClassResource>
	protected Map<String, Pair<IFile, URI>> availableClasses = new HashMap<String, Pair<IFile, URI>>
	protected IContainer baseDir

	XtendTypeDeclaration currentType

	protected ClassLoader injectedClassLoader

	private ResourceSet rs

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

	def List<XtendClassResource> getUsedClasses() {
		usedClasses
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
		if (currentType != null) {
			val currentTypeName = (currentType.eContainer as XtendFile).package + "." + currentType.name
			if (currentTypeName == calledType && receiver == null) {
				val calledFunc = currentType.members.findFirst[
					it instanceof XtendFunction && (it as XtendFunction).name == operation.simpleName &&
						(it as XtendFunction).parameters.size == argumentValues.size] as XtendFunction
				val newContext = context.fork
				for (var i = 0; i < argumentValues.size; i++) {
					val paramName = calledFunc.parameters.get(i).name
					newContext.newValue(QualifiedName.create(paramName), argumentValues.get(i))
				}
				try {
					val result = doEvaluate(calledFunc.expression, newContext, indicator)
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
		} 
		if (availableClasses.containsKey(calledType)) {
			val locationInfo = availableClasses.get(calledType)
			val resource = rs.getResource(locationInfo.value, true)
			val type = (resource.contents.head as XtendFile).xtendTypes.findFirst[
				name == operation.declaringType.simpleName]
			val func = type.members.filter(XtendFunction).findFirst[
				name == operation.simpleName && parameters.size == argumentValues.size]
			println("interpreting function " + func.name)
			val newContext = context.fork
			for (var i = 0; i < argumentValues.size; i++) {
				val paramName = func.parameters.get(i).name
				newContext.newValue(QualifiedName.create(paramName), argumentValues.get(i))
			}
			newContext.newValue(QualifiedName.create("this"), receiver)
			try {
				val currentTypeBefore = currentType
				currentType = type
				val result = doEvaluate(func.expression, newContext, indicator)
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
		super.invokeOperation(operation, receiver, argumentValues, context, indicator)
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
