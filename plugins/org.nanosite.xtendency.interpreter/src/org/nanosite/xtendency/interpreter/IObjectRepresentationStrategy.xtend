package org.nanosite.xtendency.interpreter

import org.eclipse.xtend.core.xtend.XtendFunction
import java.util.List
import org.eclipse.xtend.core.xtend.XtendConstructor
import org.eclipse.xtext.common.types.JvmConstructor
import org.eclipse.xtext.common.types.JvmField
import org.eclipse.xtext.xbase.XConstructorCall
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtext.common.types.util.JavaReflectAccess
import org.eclipse.xtext.common.types.access.impl.ClassFinder
import org.eclipse.xtext.common.types.util.TypeReferences

interface IObjectRepresentationStrategy {
	
	def void init(JavaReflectAccess reflectAccess, ClassFinder classFinder, IClassManager classManager, TypeReferences jvmTypes, XtendInterpreter interpreter)
	 
	def Object getFieldValue(Object object, JvmField field)
	def void setFieldValue(Object object, JvmField field, Object value)
	
	def void setStaticFieldValue(JvmField field, Object value)
	def Object getStaticFieldValue(JvmField field)
	
	def void setCreateMethodResult(Object object, XtendFunction method, List<?> arguments, Object result)
	def boolean hasCreateMethodResult(Object object, XtendFunction method, List<?> arguments)
	def Object getCreateMethodResult(Object object, XtendFunction method, List<?> arguments)
	
	def Object executeConstructorCall(XConstructorCall call, JvmConstructor constr, List<?> arguments)
	 
	def Object translateToJavaObject(Object inputObject)
	def String getQualifiedClassName(Object object)
	def String getSimpleClassName(Object object)
	
	def void initializeClass(XtendClass clazz)
	
	def boolean isInstanceOf(Object obj, String fqn)
}