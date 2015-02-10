package org.nanosite.xtendency.interpreter.tests

import java.util.ArrayList
import java.util.HashSet
import java.util.LinkedList
import org.junit.Test

import static org.junit.Assert.*
import org.nanosite.xtendency.interpreter.tests.input.BasicCreateMethodClass
import org.nanosite.xtendency.interpreter.tests.input.CreateMethodArgClass
import org.nanosite.xtendency.interpreter.tests.input.InstanceAndFields21
import java.util.AbstractList
import org.nanosite.xtendency.interpreter.tests.input.IndentationClass9Java
import org.nanosite.xtendency.interpreter.tests.input.IndentationClass8Java

class BasicTest extends AbstractInterpreterTest {
	
	private final String uri = "platform:/plugin/org.nanosite.xtendency.interpreter.tests/src/org/nanosite/xtendency/interpreter/tests/input/TestClasses.xtend"

	@Test
	def void T01_SimpleRichStringTest() {
		var file = parser.parse('''
		def static T01_SimpleRichString(){ """HelloWorld""" }
		'''.toXtendClass("SomeClass01"))
		
		val result = file.runTest("SomeClass01", "T01_SimpleRichString", null, #[])
		
		assertEquals('''HelloWorld'''.toString, result.result.toString)
	}
	
	@Test
	def void T02_RichStringWithArgument(){
		val source = '''
		def T02_RichStringWithArgument(String arg)"""Before<<arg>>After"""
		
		def static T02_InvokeRichStringWithArgument(String arg){
			new SomeClass02().T02_RichStringWithArgument(arg)
		}
		'''.toXtendClass("SomeClass02")
		
		val file = parser.parse(source)
		
		val result = file.runTest("SomeClass02", "T02_InvokeRichStringWithArgument", null, #["Between"])
		assertEquals('''Before«"Between"»After'''.toString, result.result.toString)
	}
	
	@Test
	def void T03_ForLoop(){
		val source = '''
		def static T03_ForLoop(int iterations)"""
		<<FOR i : 0..<iterations>>
		<<i>>
		<<ENDFOR>>
		"""
		'''.toXtendClass("SomeClass03")
		var file = parser.parse(source)
		
		val result = file.runTest("SomeClass03", "T03_ForLoop", null, #[4])
		
		assertEquals(
	 	'''
		«FOR i : 0..<4»
		«i»
		«ENDFOR»
		'''.toString, result.result.toString)
		
	}
	
	@Test
	def void T04_NestedForLoop(){
		val source = '''
		def T04_NestedForLoop(int is, int js)"""
		<<FOR i : 0..<is>>
			<<FOR j : 0..<js>>
				i is <<i>> and j is <<j>>
			<<ENDFOR>>
		<<ENDFOR>>
		"""
		
		def static T04_InvokeNestedForLoop(int is, int js) {
			val inst = new SomeClass04()
			inst.T04_NestedForLoop(is, js)
		}
		'''.toXtendClass("SomeClass04")
		var file = parser.parse(source)
		
		val result = file.runTest("SomeClass04", "T04_InvokeNestedForLoop", null, #[2, 3])
		
		assertEquals('''
		«FOR i : 0..<2»
			«FOR j : 0..<3»
					i is «i» and j is «j»
			«ENDFOR»
		«ENDFOR»
		'''.toString, result.result.toString)
	}
	
	@Test
	def void T05_IfThen(){
		val source = '''
		def static T05_IfThen(int input)"""
		<<IF input > 3>>
			input <<input>> is greater than 3
		<<ENDIF>>"""
		'''.toXtendClass("SomeClass05")
		
		val file = parser.parse(source)
		val resultTrue = file.runTest("SomeClass05", "T05_IfThen", null, #[8])
		val resultFalse = file.runTest("SomeClass05", "T05_IfThen", null, #[-2])
		assertEquals('''
		«IF 8 > 3»
			input «8» is greater than 3
		«ENDIF»
		'''.toString, resultTrue.result
		)
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
		
		def static T06_InvokeIfThenElse(int input) {
			val inst = new SomeClass06()
			inst.T06_IfThenElse(input)
		}
		'''.toXtendClass("SomeClass06")
		
		val file = parser.parse(source)
		val resultTrue = file.runTest("SomeClass06", "T06_InvokeIfThenElse", null,  #[17])
		val resultFalse = file.runTest("SomeClass06", "T06_InvokeIfThenElse", null, #[1])
		assertEquals('''
		«IF 17 > 3»
			input «17» is greater than 3
		«ELSE»
				input «17» is not greater than 3
		«ENDIF»
		'''.toString, resultTrue.result)
		assertEquals('''
		«IF 1 > 3»
			input «1» is greater than 3
		«ELSE»
				input «1» is not greater than 3
		«ENDIF»
		'''.toString, resultFalse.result)
	}
	
	@Test
	def void T07_BasicIndentation(){
		val source = '''
		package «PACKAGE»
		
		class IndentationClass7 {
			
		def someIndentation()"""
			this is right at the beginning
						this is three tabs away
					and two
				and one
		"""
			
			def static invoke(){
				new IndentationClass7().someIndentation
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("IndentationClass7", "invoke", null,  #[])
		assertEquals(
			'''
				this is right at the beginning
							this is three tabs away
						and two
					and one
			'''.toString, result.result.toString)
	}
	
	@Test
	def void T08_IndentationForIf(){
		val source = '''
		package «PACKAGE»
		
		class IndentationClass8 {
			def someIndentation()"""
				some string
					<<IF false>>
						false if
					<<ELSEIF false>>
						false elseif
					<<ELSEIF true>>
						true
							<<FOR i : 0..4>>
								number <<i>>
									<<IF i % 2 == 0>>
										divisible by two
									<<ELSEIF i % 3 == 0>>
										divisible by three
									<<ELSE>>
										not divisible
									<<ENDIF>>
							<<ENDFOR>>
					<<ELSE>>
						false else
					<<ENDIF>>
			"""
			
			def static invoke(){
				new IndentationClass8().someIndentation
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("IndentationClass8", "invoke", null,  #[])
		assertEquals(
			IndentationClass8Java.invoke.toString, result.result.toString)
	}
	
	@Test
	def void T09_IndentationAcrossMethods(){
		val source = '''
		package «PACKAGE»
		
		class IndentationClass9 {
			
		def someIndentation()"""
			this is right at the beginning
					and two
					<<moreIndentation>>
				and one
		"""
			
		def moreIndentation()"""
			first line
				second line
		"""
			
			def static invoke(){
				new IndentationClass9().someIndentation
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("IndentationClass9", "invoke", null,  #[])
		assertEquals(
			IndentationClass9Java.invoke.toString, result.result.toString)
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
		
		def static T11_InvokeSimpleMethodCall(){
			new SomeClass11().T11_SimpleMethodCall()
		}
		'''.toXtendClass("SomeClass11")
		
		var file = parser.parse(source)
		
		val result = file.runTest("SomeClass11", "T11_InvokeSimpleMethodCall", null, #[])
		
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
		
		def static T12_InvokeThisMethodCall(){
			val instance = new SomeClass12()
			instance.T12_ThisMethodCall()
		}
		'''.toXtendClass("SomeClass12")
		
		val file = parser.parse(source)
		
		val result = file.runTest("SomeClass12", "T12_InvokeThisMethodCall", null, #[])
		
		assertEquals("GettingStringFromOtherMethod", result.result)
	}
	
	@Test
	def void T13_SimpleDispatch(){
		val source = '''
		def static T08_SimpleDispatchInvoker(Iterable<String> strings){
			T08_SimpleDispatch(strings)
		}
		
		def static dispatch T08_SimpleDispatch(java.util.List<String> strings){
			"List"
		}
	
		def static dispatch T08_SimpleDispatch(java.util.ArrayList<String> strings){
			"ArrayList"
		}
	
		def static dispatch T08_SimpleDispatch(Iterable<String> strings){
			"Iterable"
		}
		'''.toXtendClass("SomeClass08")
		var file = parser.parse(source)
		
		val arrayListArg = new ArrayList<String>
		val listArg = new LinkedList<String>
		val iterableArg = new HashSet<String>
		assertEquals("ArrayList", file.runTest("SomeClass08", "T08_SimpleDispatchInvoker", null, #[arrayListArg]).result)
		assertEquals("List", file.runTest("SomeClass08", "T08_SimpleDispatchInvoker", null, #[listArg]).result)
		assertEquals("Iterable", file.runTest("SomeClass08", "T08_SimpleDispatchInvoker", null, #[iterableArg]).result)
	}
	
	@Test
	def void T15_BasicCreateMethod(){
		val source = '''
		def static T15_BasicCreateMethodInvoker(String input, «PACKAGE».BasicCreateMethodClass in){
			in.T15_BasicCreateMethod(input)
		}
		'''.toXtendClass("SomeClass15")
		
		val className = PACKAGE + ".BasicCreateMethodClass"
		val object = new BasicCreateMethodClass
		val file = parser.parse(source)
		val result1 = file.runTestWithClasses("SomeClass15", "T15_BasicCreateMethodInvoker",null,  #["Input", object], #[className -> uri])
		assertEquals("SomethingAppendedInBody", result1.result.toString)
		val result2 = file.runTestWithClasses("SomeClass15", "T15_BasicCreateMethodInvoker", null, #["Input", object], #[className -> uri])
		assertTrue(result1.result.identityEquals(result2.result))
		val result3 = file.runTestWithClasses("SomeClass15", "T15_BasicCreateMethodInvoker", null, #["OtherInput", object], #[className -> uri])
		assertFalse(result1.result.identityEquals(result3.result))
	}
	
	@Test
	def void T16_CreateMethodArg(){
		val source = '''
		def static T16_BasicCreateMethodInvoker(String input, «PACKAGE».CreateMethodArgClass in){
			in.T16_BasicCreateMethod(input)
		}
		'''.toXtendClass("SomeClass16")
		
		val className = PACKAGE + ".CreateMethodArgClass"
		
		val object = new CreateMethodArgClass
		
		val file = parser.parse(source)
		val result1 = file.runTestWithClasses("SomeClass16", "T16_BasicCreateMethodInvoker", null, #["Input", object], #[className -> uri])
		assertEquals("InputAppendedInBody", result1.result.toString)
		val result2 = file.runTestWithClasses("SomeClass16", "T16_BasicCreateMethodInvoker", null, #["Input", object], #[className -> uri])
		assertTrue(result1.result.identityEquals(result2.result))
	}
	
	@Test
	def void T17_Polymorphism(){
		val source = '''
		package «PACKAGE»
		
		class MainClass17 {
			def static T17_Polymorphism(){
				val list = #[new SuperClass(), new SubClass()]
				var result = ""
				list.forEach[result += doSomething]
				result
			}
		}
		'''.unescape
		val file = parser.parse(source)
		val result = file.runTestWithClasses("MainClass17", "T17_Polymorphism", null, #[], #[PACKAGE + ".SuperClass" -> uri, PACKAGE + ".SubClass" -> uri])
		
		assertEquals("From the SuperClass. From the SubClass and From the SuperClass. ", result.result)
		
	}
	
	@Test
	def void T18_PublicVariables(){
		val source = '''
		def T18_PublicVariables(){
			val instance = new «PACKAGE».ClassWithPublicMember()
			
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
		
		def static T18_InvokePublicVariables(){
			val obj = new SomeClass18()
			obj.T18_PublicVariables
		}
		'''.toXtendClass("SomeClass18")
		val file = parser.parse(source)
		val result = file.runTestWithClasses("SomeClass18", "T18_InvokePublicVariables", null, #[], #[PACKAGE + ".ClassWithPublicMember" -> uri])
		assertEquals("initialinitialsetDirectlysetDirectlysetMethodsetMethod", result.result)
	}
	
	@Test
	def void T19_StaticVariables(){
		val source = '''
		def T19_StaticVariables(){
			val instance = new «PACKAGE».ClassWithStaticMember()
			
			val initial_directGet = «PACKAGE».ClassWithStaticMember.SOMESTRING
			val initial_staticGet = «PACKAGE».ClassWithStaticMember.getStatic
			val initial_nonStaticGet = instance.getNonStatic
			
			«PACKAGE».ClassWithStaticMember.SOMESTRING = "SETDIRECTLY"
			val setDirectly_directGet = «PACKAGE».ClassWithStaticMember.SOMESTRING
			val setDirectly_staticGet = «PACKAGE».ClassWithStaticMember.getStatic
			val setDirectly_nonStaticGet = instance.getNonStatic
			
			«PACKAGE».ClassWithStaticMember.setStatic("SETSTATIC")
			val setStatic_directGet = «PACKAGE».ClassWithStaticMember.SOMESTRING
			val setStatic_staticGet = «PACKAGE».ClassWithStaticMember.getStatic
			val setStatic_nonStaticGet = instance.getNonStatic
			
			instance.setNonStatic("NONSTATIC")
			val setNonStatic_directGet = «PACKAGE».ClassWithStaticMember.SOMESTRING
			val setNonStatic_staticGet = «PACKAGE».ClassWithStaticMember.getStatic
			val setNonStatic_nonStaticGet = instance.getNonStatic
			
			val other = instance.getStatic
			
			return initial_directGet + initial_staticGet + initial_nonStaticGet
				+  setDirectly_directGet + setDirectly_staticGet + setDirectly_nonStaticGet
				+  setStatic_directGet + setStatic_staticGet + setStatic_nonStaticGet
				+  setNonStatic_directGet + setNonStatic_staticGet + setNonStatic_nonStaticGet + other
		}
		
		def static T19_InvokeStaticVariables(){
			val inst = new SomeClass19()
			inst.T19_StaticVariables
		}
		'''.toXtendClass("SomeClass19")
		val file = parser.parse(source)
		val result = file.runTestWithClasses("SomeClass19", "T19_InvokeStaticVariables", null, #[], #[PACKAGE + ".ClassWithStaticMember" -> uri])

		
		assertEquals("INITIALINITIALINITIALSETDIRECTLYSETDIRECTLYSETDIRECTLYSETSTATICSETSTATICSETSTATICNONSTATICNONSTATICNONSTATICNONSTATIC", result.result)
	}
	
	@Test
	def void T20_InstanceAndFieldsSimulated(){
		val source = '''
		package «PACKAGE»
		
		class InstanceAndFields20 {
			
			private String aString = "initialValue"
			
			def getString(){
				aString
			}
			
			def setString(String string){
				aString = string
			}
			
			def static invokeTestInstanceAndFields20(){
				new InstanceAndFields20().testInstanceAndFields
			}
			
			def testInstanceAndFields(){
				val other = new InstanceAndFields20
				var result = aString
				result += other.string
				
				other.string = "changedOther"
				result += string
				result += other.string
				
				string = "changedThis"
				result += string
				result += other.string
				
				result += this.equals(other)
				result += this.equals(this)
				result += other.equals(other)
				
				result += this.toString.contains("InstanceAndFields")
				result += other.toString.contains("InstanceAndFields")
				result += this.toString.equals(other.toString)
				result
			}
		}
		
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("InstanceAndFields20", "invokeTestInstanceAndFields20", null, #[])
		assertEquals("initialValueinitialValueinitialValuechangedOtherchangedThischangedOtherfalsetruetruetruetruefalse", result.result)
	}
	
	def void T21_InstanceAndFieldsNative(){
		val source = '''
		def static invokeTestInstanceAndFields21(){
			new «PACKAGE».InstanceAndFields21().testInstanceAndFields
		}
		'''.toXtendClass("SomeClass21")
		val file = parser.parse(source)
		val result = file.runTestWithClasses("SomeClass21", "invokeTestInstanceAndFields21", null, #[], #[PACKAGE + ".InstanceAndFields21" -> uri])
		val resultPair = result.result as Pair<String, Object>
		assertEquals("initialValueinitialValueinitialValuechangedOtherchangedThischangedOtherfalsetruetruetruetruefalse", resultPair.key)
		assertTrue(resultPair.value instanceof InstanceAndFields21)
	}
	
	@Test
	def void T22_XtendImplementsJava(){
		val source = '''
		package «PACKAGE»
		
		class MyRunnable22 implements Runnable {
			public static String state = "INITIAL"
			
			static def String test22(){
				val r = new MyRunnable22()
				// we just check if Thread accepts the object
				val t = new Thread(r)
				r.run
				return state
			}
			
			override run(){
				state = "CHANGED"
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("MyRunnable22", "test22", null, #[])
		assertEquals("CHANGED", result.result)
	}
	
	
	@Test
	def void T23_XtendExtendsJava(){
		val source = '''
		package «PACKAGE»
		
		class XtendClass23 extends XtendSuperClass23 {
			new(int number) {
				this("Input" + number)
				state += "byMain"
			}
			
			new(String in){
				super(in + "BYXTEND")
				state += "bythis"
			}
			
			def String getInternalState(){
				state
			}
			
			def static String construct(){
				val obj = new XtendClass23(2)
				obj.internalState
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTestWithClasses("XtendClass23", "construct", null, #[], #[PACKAGE + ".XtendSuperClass23" -> uri])
		assertEquals("initialInput2BYXTENDbyXtendByXtendbythisbyMain", result.result)
	}
	
	@Test
	def void T24_Anonymous(){
		val source = '''
		package «PACKAGE»
		import java.util.ArrayList
		
		class Anonymous24 {
			
			private String outsideState = "initial"
			
			def static String invoke(){
				new Anonymous24().invoke2()
			}
			
			def String invoke2(){
				val localVar = "localString"
				val lst = new ArrayList(10){
					override get(int index) {
						"from" + localVar
					}
					
				}
				lst.add("test")
				val obj = new Runnable(){
					override run(){
						outsideState = "changed"
					}
				}
				
				val listContent = lst.get(0) ?: "null"
							
				obj.run
				return listContent + outsideState
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTestWithClasses("Anonymous24", "invoke", null, #[], #[])
		assertEquals("fromlocalStringchanged", result.result)
	}
	
	@Test
	def void T25_superCall(){
		val source = '''
		package «PACKAGE»
		
		class XtendC extends JavaB {
			override a(){
				"a in C"
			}
		}
		
		class XtendXtendB extends JavaA {
			def b(){
				a() + super.a()
			}
		}
		
		class XtendXtendC extends XtendXtendB {
			override String a(){
				"a in C"
			}
		}
		
		class Invoker {
			static def String invoke(){
				new XtendXtendC().b() + new XtendC().b()
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTestWithClasses("Invoker", "invoke", null, #[], #[PACKAGE + ".JavaA" -> uri, PACKAGE + ".JavaB" -> uri])
		assertEquals("a in Ca in Aa in Ca in A", result.result)
	}
	
	@Test
	def void T26_Reflection(){
		val source = '''
		package «PACKAGE»
		
		class SomeClass26 extends JavaA{
			
		}
		
		class OtherClass26 extends SomeClass26{
			static def String doReflectiveThings(){
				var result = ""
				val c1 = JavaA
				val c2 = SomeClass26
				val c3 = typeof(OtherClass26)
				
				val c32 = OtherClass26
				result += c1.simpleName
				result += c2.simpleName 
				result += c3.simpleName
				
				result += c3 === c32 // true
				result += c3.isAssignableFrom(c2) // false
				result += c2.isAssignableFrom(c1) // false
				result += c2.isAssignableFrom(c3) // true
				result += c1.isAssignableFrom(c2) // true
				
				val ocInstance = c3.newInstance
				val c33 = ocInstance.class
				result += c33 === c3
				val amethod = c3.getMethod("a")
				result += amethod.invoke(ocInstance)
				result
			}
			
			override a(){
				"a in OC26" + super.a
			}	
		}
		
		
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("OtherClass26", "doReflectiveThings", null, #[])
		assertEquals("JavaASomeClass26OtherClass26truefalsefalsetruetruetruea in OC26a in A", result.result)
	}
	
	@Test
	def void T27_InterpreterExecution(){
		val source = '''
		package «PACKAGE»
		
		class XtendClass27 {
			
			static def String invoke(){
				val result = ""
				val xc1 = new XtendClass27()
				result += xc1.doExecutionCheck
				val m1 = xc1.class.getDeclaredMethod("doExecutionCheck")
				result += m1.invoke(xc1)
				
				val xc2 = XtendClass27.newInstance as XtendClass27
				result += xc2.doExecutionCheck
				val m2 = xc2.class.getDeclaredMethod("doExecutionCheck")
				result += m2.invoke(xc2)
				
				val xec1 = new XtendExecutionCheckClass()
				result += xec1.doExecutionCheck
				val me1 = xec1.class.getDeclaredMethod("doExecutionCheck")
				result += me1.invoke(xec1)
				
				val xec2 = XtendExecutionCheckClass.newInstance as XtendExecutionCheckClass
				result += xec2.doExecutionCheck
				val me2 = xec2.class.getDeclaredMethod("doExecutionCheck")
				result += me2.invoke(xec2)
				
				result += new JavaExecutionCheckClass().doExecutionCheck()
				
				return result
			}
			
			def boolean doExecutionCheck(){
				return org.nanosite.xtendency.interpreter.tests.BasicTest.checkInterpreterExecution()
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTestWithClasses("XtendClass27", "invoke", null, #[], #[PACKAGE + ".XtendExecutionCheckClass" -> uri])
		assertEquals("truetruetruetruetruetruetruetruefalse", result.result)
	}
	
	@Test
	def void T28_OverriddenPrivateMethod(){
		val source = '''
		package «PACKAGE»
		
		class Super28 {
			def private String privateMethod(){
				"superResult"
			}
			
			def accessMethod(){
				privateMethod
			}
			
			def static String invoke(){
				new Sub28().accessMethod()
			}
		}
		
		class Sub28 extends Super28 {
			def private privateMethod(){
				"subResult"
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("Super28", "invoke", null, #[])
		assertEquals("superResult", result.result)
	}
	
	@Test
	def void T29_Interface(){
		val source = '''
		package «PACKAGE»
		
		interface IF29 {
			def String getSomeString()
		}
		
		interface IF29_2 {
			def IF29 getSomeIF(IF29 in)
		}
		
		class Simple29 implements IF29 {
			override getSomeString(){
				"static"
			}
		}
		
		class C29 implements IF29, IF29_2 {
			
			private String input
			
			new(String in){
				this.input = in
			}
			
			override getSomeString(){
				input
			}
			

			
			static def invoke(){
				var result = ""
				var IF29 i = null
				var IF29 i2 = null
				if (true){
					i = new C29("someInput")
					i2 = new Simple29()
				}else{
					i = new Simple29()
				}
				val inst = new C29("anInput")
				val inst2 = new C29("otherInput")
				result += i.someString
				result += i2.someString
				
				val IF29_2 i3 = inst
				val i4 = i3.getSomeIF(inst2)
				result += i4.someString
				
			}
			
			override getSomeIF(IF29 in) {
				val toReturn = "changed" + in.someString
				
				return new IF29(){
					override getSomeString(){
						toReturn
					}
				}
			}
			
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("C29", "invoke", null, #[])
		assertEquals("someInputstaticchangedotherInput", result.result)
	}
	
	@Test
	def void T30_Enums(){
		val source = '''
		package «PACKAGE»
		
		enum Direction {
			NORTH, SOUTH, EAST, WEST
		}
		
		class EnumTest30 {
			def Direction getWest(){
				return Direction.WEST
			}
			
			def addNorth(Direction d){
				"NORTH" + d
			}
			
			def static invoke(){
				val inst = new EnumTest30()
				return inst.addNorth(inst.west)
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("EnumTest30", "invoke", null, #[])
		assertEquals("NORTHWEST", result.result)
	}
	
	@Test
	def void T31_Annotations(){
		val source = '''
		package «PACKAGE»
		
		@org.nanosite.xtendency.interpreter.tests.input.TestAnnotation
		class Annotated31 {
			
			def static String invoke(){
				Annotated31.declaredAnnotations.head.annotationType.canonicalName
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("Annotated31", "invoke", null, #[])
		assertEquals("org.nanosite.xtendency.interpreter.tests.input.TestAnnotation", result.result)
	}
	
	@Test
	def void T32_SwitchCase(){
		val source = '''
		package «PACKAGE»
		
		class SuperSwitchTest32 {
			private String input
			
			new(String in){
				this.input = in
			}
			
			def getInput(){
				input
			}
			
			
		}
		
		class SwitchTest32 extends SuperSwitchTest32 {
			
			new(String in){
				super(in)
			}
			
			def static invoke(){
				var result = ""
				result += getSwitch(new SwitchTest32("branch1"))
				result += getSwitch(new SwitchTest32("whatever"))
				result += getSwitch(new SuperSwitchTest32("something"))
				result += getSwitch("aString")
				result
			}
			
			def static getSwitch(Object o){
				switch(o){
					SuperSwitchTest32 case o.input == "branch1" : "BRANCH1"
					SwitchTest32 : "BRANCH2"
					default : "DEFAULT"
				}
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("SwitchTest32", "invoke", null, #[])
		assertEquals("BRANCH1BRANCH2DEFAULTDEFAULT", result.result)
	}
	
	@Test
	def void T33_AnonymousClassLambda(){
		val source = '''
		package «PACKAGE»
		
		class Invoker33 {
			
			public static String state = "BEFORE"
			
			def static invoke(){
				var result = state
				val t = new Thread([| Invoker33.state = "AFTER"])
				t.start
				t.join
				result += state
				return result
			}
		}
		'''.unescape
		
		val file = parser.parse(source)
		val result = file.runTest("Invoker33", "invoke", null, #[])
		assertEquals("BEFOREAFTER", result.result)
	}
	
	static def boolean checkInterpreterExecution(){
		val st = Thread.currentThread.stackTrace
		st.get(2).methodName != "doExecutionCheck"
	}
}
