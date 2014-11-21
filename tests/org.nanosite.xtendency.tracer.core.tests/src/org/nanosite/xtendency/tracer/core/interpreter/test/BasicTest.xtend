package org.nanosite.xtendency.tracer.core.interpreter.test

import java.util.ArrayList
import java.util.HashSet
import java.util.LinkedList
import org.junit.Test

import static org.junit.Assert.*
import org.nanosite.xtendency.tracer.core.interpreter.test.input.CreateMethodArgClass
import org.nanosite.xtendency.tracer.core.interpreter.test.input.BasicCreateMethodClass

class BasicTest extends AbstractInterpreterTest {
	
	private final String uri = "platform:/plugin/org.nanosite.xtendency.tracer.core.tests/src/org/nanosite/xtendency/tracer/core/interpreter/test/input/TestClasses.xtend"

	@Test
	def void T01_SimpleRichStringTest() {
		var file = parser.parse('''
		def T01_SimpleRichString(){ """HelloWorld""" }
		'''.toXtendClass("SomeClass01"))
		
		val result = file.runTest("SomeClass01", "T01_SimpleRichString", #[])
		
		assertEquals("HelloWorld", result.result.toString)
	}
	
	@Test
	def void T021_RichStringWithArgument(){
		val source = '''
		def T02_RichStringWithArgument(String arg)"""Before<<arg>>After"""
		'''.toXtendClass("SomeClass02")
		
		val file = parser.parse(source)
		
		val result = file.runTest("SomeClass02", "T02_RichStringWithArgument", #["Between"])
		assertEquals("BeforeBetweenAfter", result.result.toString)
	}
	
	@Test
	def void T031_ForLoop(){
		val source = '''
		def T03_ForLoop(int iterations)"""
		<<FOR i : 0..<iterations>>
		<<i>>
		<<ENDFOR>>
		"""
		'''.toXtendClass("SomeClass03")
		var file = parser.parse(source)
		
		val result = file.runTest("SomeClass03", "T03_ForLoop", #[4])
		
		assertEquals(
	 	'''0
1
2
3
'''.toString, result.result.toString)
		
	}
	
	@Test
	def void T041_NestedForLoop(){
		val source = '''
		def T04_NestedForLoop(int is, int js)"""
		<<FOR i : 0..<is>>
		<<FOR j : 0..<js>>
		i is <<i>> and j is <<j>>
		<<ENDFOR>>
		<<ENDFOR>>
		"""
		'''.toXtendClass("SomeClass04")
		var file = parser.parse(source)
		
		val result = file.runTest("SomeClass04", "T04_NestedForLoop", #[2, 3])
		
		assertEquals(
			'''
			i is 0 and j is 0
			i is 0 and j is 1
			i is 0 and j is 2
			i is 1 and j is 0
			i is 1 and j is 1
			i is 1 and j is 2
			'''.toString, result.result.toString)
	}
	
	@Test
	def void T05_IfThen(){
		val source = '''
		def T05_IfThen(int input)"""
		<<IF input > 3>>
		input <<input>> is greater than 3
		<<ENDIF>>"""
		'''.toXtendClass("SomeClass05")
		
		val file = parser.parse(source)
		println("resource is " + file.eResource)
		val resultTrue = file.runTest("SomeClass05", "T05_IfThen", #[8])
		val resultFalse = file.runTest("SomeClass05", "T05_IfThen", #[-2])
		assertEquals("input 8 is greater than 3\n", resultTrue.result)
		assertEquals("", resultFalse.result)
	}
	
	@Test
	def void T06_IfThenElse(){
		val source = '''
		def T06_IfThenElse(int input)"""
		<<IF input > 3>>
		input <<input>> is greater than 3
		<<ELSE>>
		input <<input>> is not greater than 3
		<<ENDIF>>"""
		'''.toXtendClass("SomeClass06")
		
		val file = parser.parse(source)
		val resultTrue = file.runTest("SomeClass06", "T06_IfThenElse", #[17])
		val resultFalse = file.runTest("SomeClass06", "T06_IfThenElse", #[1])
		assertEquals("input 17 is greater than 3", resultTrue.result)
		assertEquals("input 1 is not greater than 3", resultFalse.result)
	}
	
	@Test
	def void T11_LocalMethodCall(){
		val source = '''
		def private T11_HelperMethod(){
			"FromOtherMethod"
		}
	
		def T11_SimpleMethodCall(){
			"GettingString" + T11_HelperMethod
		}
		'''.toXtendClass("SomeClass11")
		
		var file = parser.parse(source)
		
		val result = file.runTest("SomeClass11", "T11_SimpleMethodCall", #[])
		
		assertEquals("GettingStringFromOtherMethod", result.result)
	}
	
	@Test
	def void T12_ThisMethodCall(){
		val source = '''
		def private T11_HelperMethod(){
			"FromOtherMethod"
		}
		
		def T12_ThisMethodCall(){
			"GettingString" + this.T11_HelperMethod
		}
		'''.toXtendClass("SomeClass12")
		
		val file = parser.parse(source)
		
		val result = file.runTest("SomeClass12", "T12_ThisMethodCall", #[])
		
		assertEquals("GettingStringFromOtherMethod", result.result)
	}
	
	@Test
	def void T081_SimpleDispatch(){
		val source = '''
		def T08_SimpleDispatchInvoker(Iterable<String> strings){
			T08_SimpleDispatch(strings)
		}
		
		def dispatch T08_SimpleDispatch(java.util.List<String> strings){
			"List"
		}
	
		def dispatch T08_SimpleDispatch(java.util.ArrayList<String> strings){
			"ArrayList"
		}
	
		def dispatch T08_SimpleDispatch(Iterable<String> strings){
			"Iterable"
		}
		'''.toXtendClass("SomeClass08")
		var file = parser.parse(source)
		
		val arrayListArg = new ArrayList<String>
		val listArg = new LinkedList<String>
		val iterableArg = new HashSet<String>
		assertEquals("ArrayList", file.runTest("SomeClass08", "T08_SimpleDispatchInvoker", #[arrayListArg]).result)
		assertEquals("List", file.runTest("SomeClass08", "T08_SimpleDispatchInvoker", #[listArg]).result)
		assertEquals("Iterable", file.runTest("SomeClass08", "T08_SimpleDispatchInvoker", #[iterableArg]).result)
	}
	
	@Test
	def void T15_BasicCreateMethod(){
		val source = '''
		def T15_BasicCreateMethodInvoker(String input, org.nanosite.xtendency.tracer.core.interpreter.test.input.BasicCreateMethodClass in){
			in.T15_BasicCreateMethod(input)
		}
		'''.toXtendClass("SomeClass15")
		
		val className = "org.nanosite.xtendency.tracer.core.interpreter.test.input.BasicCreateMethodClass"
		val object = new BasicCreateMethodClass
		val file = parser.parse(source)
		val result1 = file.runTestWithClasses("SomeClass15", "T15_BasicCreateMethodInvoker", #["Input", object], #[className -> uri])
		assertEquals("SomethingAppendedInBody", result1.result.toString)
		val result2 = file.runTestWithClasses("SomeClass15", "T15_BasicCreateMethodInvoker", #["Input", object], #[className -> uri])
		assertTrue(result1.result.identityEquals(result2.result))
		val result3 = file.runTestWithClasses("SomeClass15", "T15_BasicCreateMethodInvoker", #["OtherInput", object], #[className -> uri])
		assertFalse(result1.result.identityEquals(result3.result))
	}
	
	@Test
	def void T16_CreateMethodArg(){
		val source = '''
		def T16_BasicCreateMethodInvoker(String input, org.nanosite.xtendency.tracer.core.interpreter.test.input.CreateMethodArgClass in){
			in.T16_BasicCreateMethod(input)
		}
		'''.toXtendClass("SomeClass16")
		
		val className = "org.nanosite.xtendency.tracer.core.interpreter.test.input.CreateMethodArgClass"
		
		val object = new CreateMethodArgClass
		
		val file = parser.parse(source)
		val result1 = file.runTestWithClasses("SomeClass16", "T16_BasicCreateMethodInvoker", #["Input", object], #[className -> uri])
		assertEquals("InputAppendedInBody", result1.result.toString)
		val result2 = file.runTestWithClasses("SomeClass16", "T16_BasicCreateMethodInvoker", #["Input", object], #[className -> uri])
		assertTrue(result1.result.identityEquals(result2.result))
	}
	
	@Test
	def void T17_Polymorphism(){
		println("Starting Polymorphism")
		val source = '''
		package org.nanosite.xtendency.tracer.core.interpreter.test.input
		
		class MainClass17 {
			def T17_Polymorphism(){
				val list = #[new SuperClass(), new SubClass()]
				var result = ""
				list.forEach[result += doSomething]
				result
			}
		}
		'''.unescape
		val file = parser.parse(source)
		val result = file.runTestWithClasses("MainClass17", "T17_Polymorphism", #[], #["org.nanosite.xtendency.tracer.core.interpreter.test.input.SuperClass" -> uri, "org.nanosite.xtendency.tracer.core.interpreter.test.input.SubClass" -> uri])
		
		assertEquals("From the SuperClass. From the SubClass and From the SuperClass. ", result.result)
		
	}
	
	@Test
	def void T18_PublicVariables(){
		println("starting publicvariables")
		val source = '''
		def T18_PublicVariables(){
			val instance = new org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithPublicMember()
			
			val initial_directGet = instance.someString
			val initial_methodGet = instance.get
			
			instance.someString = "setDirectly"
			val setDirectly_directGet = instance.someString
			val setDirectly_methodGet = instance.get
			
			instance.set("setMethod")
			val setMethod_directGet = instance.someString
			val setMethod_methodGet = instance.get
			
			return initial_directGet + initial_methodGet + setDirectly_directGet + setDirectly_methodGet + setMethod_directGet + setMethod_methodGet
		}
		'''.toXtendClass("SomeClass18")
		val file = parser.parse(source)
		val result = file.runTestWithClasses("SomeClass18", "T18_PublicVariables", #[], #["org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithPublicMember" -> uri])
		assertEquals("initialinitialsetDirectlysetDirectlysetMethodsetMethod", result.result)
	}
	
	@Test
	def void T19_StaticVariables(){
		val source = '''
		def T19_StaticVariables(){
			val instance = new org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember()
			
			val initial_directGet = org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember.SOMESTRING
			val initial_staticGet = org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember.getStatic
			val initial_nonStaticGet = instance.getNonStatic
			
			org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember.SOMESTRING = "SETDIRECTLY"
			val setDirectly_directGet = org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember.SOMESTRING
			val setDirectly_staticGet = org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember.getStatic
			val setDirectly_nonStaticGet = instance.getNonStatic
			
			org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember.setStatic("SETSTATIC")
			val setStatic_directGet = org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember.SOMESTRING
			val setStatic_staticGet = org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember.getStatic
			val setStatic_nonStaticGet = instance.getNonStatic
			
			instance.setNonStatic("NONSTATIC")
			val setNonStatic_directGet = org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember.SOMESTRING
			val setNonStatic_staticGet = org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember.getStatic
			val setNonStatic_nonStaticGet = instance.getNonStatic
			
			val other = instance.getStatic
			
			return initial_directGet + initial_staticGet + initial_nonStaticGet
				+  setDirectly_directGet + setDirectly_staticGet + setDirectly_nonStaticGet
				+  setStatic_directGet + setStatic_staticGet + setStatic_nonStaticGet
				+  setNonStatic_directGet + setNonStatic_staticGet + setNonStatic_nonStaticGet + other
		}
		'''.toXtendClass("SomeClass19")
		val file = parser.parse(source)
		val result = file.runTestWithClasses("SomeClass19", "T19_StaticVariables", #[], #["org.nanosite.xtendency.tracer.core.interpreter.test.input.ClassWithStaticMember" -> uri])

		
		assertEquals("INITIALINITIALINITIALSETDIRECTLYSETDIRECTLYSETDIRECTLYSETSTATICSETSTATICSETSTATICNONSTATICNONSTATICNONSTATICNONSTATIC", result.result)
	}
	
	
}
