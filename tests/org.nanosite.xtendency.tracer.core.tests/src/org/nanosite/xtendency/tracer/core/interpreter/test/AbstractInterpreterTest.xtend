package org.nanosite.xtendency.tracer.core.interpreter.test

import com.google.inject.Inject
import org.eclipse.xtext.junit4.util.ParseHelper
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import java.util.List
import org.eclipse.xtend.core.xtend.XtendFunction
import org.nanosite.xtendency.tracer.core.ChattyEvaluationContext
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.junit4.InjectWith
import org.junit.runner.RunWith
import org.eclipse.xtext.junit4.XtextRunner
import org.eclipse.xtext.resource.XtextResourceSet
import org.eclipse.xtext.ui.resource.IResourceSetProvider
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.common.util.URI
import org.nanosite.xtendency.tracer.core.TracingInterpreter
import org.nanosite.xtendency.tracer.core.StandaloneClassManager

@InjectWith(XtendencyInjectorProvider)
@RunWith(XtextRunner)
class AbstractInterpreterTest {
	public static final String PACKAGE = "org.nanosite.xtendency.tracer.core.interpreter.test.input"
	
	@Inject
	protected ParseHelper<XtendFile> parser 
	
	@Inject
	protected TracingInterpreter interpreter
	
	@Inject
	protected StandaloneClassManager classManager
	
	def <T extends Object> runTest(XtendFile file, String className, String methodName, Object instance, List<T> arguments){
		runTestWithClasses(file, className, methodName, instance, arguments, #[])
	}
	
	def <T extends Object> runTestWithClasses(XtendFile file, String className, String methodName, Object instance, List<T> arguments, List<Pair<String, String>> additionalClasses){
		classManager.init(file.eResource.resourceSet)
		val XtendTypeDeclaration type = file.xtendTypes.findFirst[name == className]
		val XtendFunction func = type.members.filter(XtendFunction).findFirst[name == methodName]
		
		file.xtendTypes.forEach[clazz |
			val fqn = file.package + "." + clazz.name
			classManager.addAvailableClass(fqn, file)
		]
		additionalClasses.forEach[
			classManager.addAvailableClass(key, URI.createURI(value))
		]
		val result = interpreter.evaluateMethod(func, instance, classManager, arguments)
		if (result.exception != null)
			throw result.exception
		result
	}
	
	def String toXtendClass(CharSequence methods, String className)'''
	package «PACKAGE»
	
	class «className» {
		«methods.unescape»
	}
	'''
	
	def String unescape(CharSequence escaped){
		escaped.toString.replaceAll("\"\"\"", "'''").replaceAll("<<", "«").replaceAll(">>", "»")
	}
}