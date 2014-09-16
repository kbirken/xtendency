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

class XtendInterpreter extends XbaseInterpreter {

	@Inject
	protected RichStringProcessor richStringProcessor

	@Inject
	protected Provider<DefaultIndentationHandler> indentationHandler

	XtendTypeDeclaration currentType

	protected ClassLoader injectedClassLoader

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
			val result = new URLClassLoader(classPathUrls, injectedClassLoader)
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
				return doEvaluate(calledFunc.expression, newContext, indicator)
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
}
