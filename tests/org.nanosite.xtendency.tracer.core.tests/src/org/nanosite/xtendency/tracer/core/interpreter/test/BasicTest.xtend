package org.nanosite.xtendency.tracer.core.interpreter.test

import org.junit.Test
import org.eclipse.core.resources.IProject
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.emf.common.util.URI

import static org.junit.Assert.*
import java.util.ArrayList
import java.util.LinkedList
import java.util.HashSet

class BasicTest extends AbstractInterpreterTest {

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
	def void T05_IfThenElse(){
		val source = '''
		def T05_IfThenElse(int input)"""
		<<IF input > 3>>
		input <<input>> is greater than 3
		<<ELSE>>
		input <<input>> is not greater than 3
		<<ENDIF>>"""
		'''.toXtendClass("SomeClass05")
		
		val file = parser.parse(source)
		val resultTrue = file.runTest("SomeClass05", "T05_IfThenElse", #[17])
		val resultFalse = file.runTest("SomeClass05", "T05_IfThenElse", #[1])
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
		def T15_BasicCreateMethodInvoker(String input){
			T15_BasicCreateMethod(input)
		}
		
		def create result : new StringBuffer("Something") T15_BasicCreateMethod(String input){
			result.append("AppendedInBody")
		}
		'''.toXtendClass("SomeClass15")
		
		val file = parser.parse(source)
		val result1 = file.runTest("SomeClass15", "T15_BasicCreateMethodInvoker", #["Input"])
		assertEquals("SomethingAppendedInBody", result1.result.toString)
		val result2 = file.runTest("SomeClass15", "T15_BasicCreateMethodInvoker", #["Input"])
		assertTrue(result1.result.identityEquals(result2.result))
		val result3 = file.runTest("SomeClass15", "T15_BasicCreateMethodInvoker", #["OtherInput"])
		assertFalse(result1.result.identityEquals(result3.result))
	}
	
	@Test
	def void T16_CreateMethodArg(){
		val source = '''
		def T16_BasicCreateMethodInvoker(String input){
			T16_BasicCreateMethod(input)
		}
		
		def create result : new StringBuffer(input) T16_BasicCreateMethod(String input){
			result.append("AppendedInBody")
		}
		'''.toXtendClass("SomeClass16")
		
		val file = parser.parse(source)
		val result1 = file.runTest("SomeClass16", "T16_BasicCreateMethodInvoker", #["Input"])
		assertEquals("InputAppendedInBody", result1.result.toString)
		val result2 = file.runTest("SomeClass16", "T16_BasicCreateMethodInvoker", #["Input"])
		assertTrue(result1.result.identityEquals(result2.result))
	}
	
	
}
