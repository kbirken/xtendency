package org.nanosite.xtendency.tracer.core.interpreter.test

import com.google.inject.Inject
import org.eclipse.xtext.junit4.util.ParseHelper
import org.eclipse.xtend.core.xtend.XtendFile
import org.nanosite.xtendency.tracer.core.StandaloneXtendInterpreter
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import java.util.List
import org.eclipse.xtend.core.xtend.XtendFunction
import org.nanosite.xtendency.tracer.core.ChattyEvaluationContext
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.junit4.InjectWith
import org.junit.runner.RunWith
import org.eclipse.xtext.junit4.XtextRunner

@InjectWith(RuntimeInjectorProvider)
@RunWith(XtextRunner)
class AbstractInterpreterTest {
	@Inject
	protected ParseHelper<XtendFile> parser
	
	@Inject
	protected StandaloneXtendInterpreter interpreter
	
	def <T extends Object> runTest(XtendFile file, String className, String methodName, List<T> arguments){
		val XtendTypeDeclaration type = file.xtendTypes.findFirst[name == className]
		val XtendFunction func = type.members.filter(XtendFunction).findFirst[name == methodName]
		
		val globalContext = new ChattyEvaluationContext
		val methodContext = globalContext.fork
		
		if (arguments.size != func.parameters.size)
			throw new IllegalArgumentException("Arguments and parameters don't match")
			
		for (i : 0..<arguments.size){
			methodContext.newValue(QualifiedName.create(func.parameters.get(i).name), arguments.get(i))
		}
		
		//interpreter.configure(classContainer)
		//interpreter.addProjectToClasspath(JavaCore.create(classContainer))
		interpreter.currentType = type
		interpreter.globalScope = globalContext
		return interpreter.evaluate(func.expression, methodContext, CancelIndicator.NullImpl)
	}
	
	def String toXtendClass(CharSequence methods, String className)'''
	package org.nanosite.xtendency.tracer.core.tests
	
	class «className» {
		«methods.unescape»
	}
	'''
	
	def String unescape(CharSequence escaped){
		escaped.toString.replaceAll("\"\"\"", "'''").replaceAll("<<", "«").replaceAll(">>", "»")
	}
}