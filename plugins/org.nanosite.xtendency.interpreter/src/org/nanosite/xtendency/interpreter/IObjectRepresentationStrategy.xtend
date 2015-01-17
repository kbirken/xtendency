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
import org.eclipse.xtend.core.xtend.AnonymousClass
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.xtext.common.types.JvmType
import java.lang.reflect.Method

interface IObjectRepresentationStrategy {
	
	def void init(JavaReflectAccess reflectAccess, ClassFinder classFinder, IClassManager classManager, TypeReferences jvmTypes, IInterpreterAccess interpreter)
	 
	def Object getFieldValue(Object object, JvmField field)
	def void setFieldValue(Object object, JvmField field, Object value)
	
	def void setStaticFieldValue(JvmField field, Object value)
	def Object getStaticFieldValue(JvmField field)
	
	def void setCreateMethodResult(Object object, XtendFunction method, List<?> arguments, Object result)
	def boolean hasCreateMethodResult(Object object, XtendFunction method, List<?> arguments)
	def Object getCreateMethodResult(Object object, XtendFunction method, List<?> arguments)
	
	def Object executeConstructorCall(XConstructorCall call, JvmConstructor constr, List<?> arguments)
	 
	def String getQualifiedClassName(Object object)
	def String getSimpleClassName(Object object)
	
	def void initializeClass(XtendTypeDeclaration clazz)
	
	def boolean isInstanceOf(Object obj, String fqn)
	
	def Object executeAnonymousClassConstructor(AnonymousClass clazz, List<?> arguments, IEvaluationContext context)
	def IEvaluationContext fillAnonymousClassMethodContext(IEvaluationContext context, JvmOperation op, Object object)
	
	def Class<?> getClass(JvmType type, int arrayDimensions)
	
	
	def Method getJavaOnlyMethod(Object instance, JvmOperation method)
}