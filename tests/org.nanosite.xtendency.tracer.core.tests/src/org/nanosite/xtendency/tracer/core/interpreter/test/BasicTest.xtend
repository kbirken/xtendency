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
	
	
}
