package org.nanosite.xtendency.tracer.core.tests

import com.google.inject.Injector
import org.eclipse.xtend.core.XtendStandaloneSetup
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationContext
import org.junit.Before
import org.junit.Test
import org.nanosite.xtendency.tracer.core.TracingInterpreter
import org.nanosite.xtendency.tracer.core.util.XtendHelpers
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext

class TracerTest {

	val MODEL_PATH = "src/org/nanosite/xtendency/tracer/core/models/"

	Injector injector = null
	XtendHelpers aux = null

	@Before
	def void setUp() throws Exception {
		injector = new XtendStandaloneSetup().createInjectorAndDoEMFRegistration()
		aux = injector.getInstance(typeof(XtendHelpers))
	}

	@Test
	def void test01() {
		val xtendFile = aux.load(MODEL_PATH + "SampleGenerator.xtend")
		
		val xclass = xtendFile.xtendTypes.get(0) as XtendClass
		val xfunc = xclass.members.get(0) as XtendFunction
		
		// create context for arguments
		val context = new DefaultEvaluationContext
		context.newValue(QualifiedName::create("isHello"), true)
		context.newValue(QualifiedName::create("who"), "World")
		
		runInterpreter(xfunc, context)
	}


	@Test
	def void test02() {
		val xtendFile = aux.load(MODEL_PATH + "SampleGenerator.xtend")
		
		val xclass = xtendFile.xtendTypes.get(0) as XtendClass
		val xfunc = xclass.members.get(0) as XtendFunction
		
		// create context for arguments
		val context = new DefaultEvaluationContext
		context.newValue(QualifiedName::create("isHello"), false)
		context.newValue(QualifiedName::create("who"), "World")
		
		runInterpreter(xfunc, context)
	}

	def private runInterpreter (XtendFunction xfunc, IEvaluationContext context) {
		val interpreter = injector.getInstance(typeof(TracingInterpreter))
		//TODO: adapt to new interpreter API, this no longer works
//		val res = interpreter.evaluate(xfunc.expression, context, CancelIndicator::NullImpl)
//		if (res.exception!=null) {
//			println("XbaseInterpreter: " + res.exception.toString)
//		} 
//		
//		if (res.result != null) {
//			println("Evaluation result:")
//			println(res.result)
//		}
//		
//		println
	}
}