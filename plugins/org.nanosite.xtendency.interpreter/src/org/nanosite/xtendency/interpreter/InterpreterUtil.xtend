package org.nanosite.xtendency.interpreter

import org.eclipse.xtext.xbase.interpreter.impl.EvaluationException
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtext.common.types.access.impl.ClassFinder
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.core.xtend.XtendFunction
import java.util.Map
import java.util.List
import java.util.HashMap
import org.eclipse.xtext.common.types.JvmOperation
import org.eclipse.xtext.common.types.JvmDeclaredType
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.xtend.core.xtend.XtendExecutable
import org.eclipse.xtext.common.types.JvmExecutable
import org.eclipse.xtend.core.xtend.XtendConstructor
import org.eclipse.xtext.common.types.JvmConstructor
import java.lang.reflect.Method

class InterpreterUtil {
	
	private ClassFinder classFinder
	
	new(ClassFinder classFinder){
		this.classFinder = classFinder
	}
	
	def int compareTypes(JvmTypeReference t1, JvmTypeReference t2) {
		val t1Type = classFinder.forName(t1.type.qualifiedName)
		val t2Type = classFinder.forName(t2.type.qualifiedName)
		val t2get1 = t2Type.isAssignableFrom(t1Type)
		val t1get2 = t1Type.isAssignableFrom(t2Type)
		if (t2get1) {
			if (t1get2) {
				throw new IllegalArgumentException
			} else {
				-1
			}
		} else if (t1get2) {
			1
		} else {
			0
		}
	}
	
	def <T> T getParent(EObject eo, Class<T> clazz){
		if (clazz.isInstance(eo)){
			return eo as T
		}else{
			eo.eContainer?.getParent(clazz)
		}
	}
	
	def int compareFunctions(XtendFunction f1, XtendFunction f2) {
		for (i : 0 ..< f1.parameters.size) {
			val currentParam = f1.parameters.get(i).parameterType.compareTypes(f2.parameters.get(i).parameterType)
			if (currentParam != 0)
				return currentParam
		}
		throw new IllegalArgumentException
	}

	def Map<List<?>, Object> safeGet(Map<Pair<XtendFunction, Object>, Map<List<?>, Object>> map,
		Pair<XtendFunction, Object> k) {
		if (map.containsKey(k)) {
			return map.get(k)
		} else {
			val result = new HashMap<List<?>, Object>
			map.put(k, result)
			result
		}
	}
	
	def boolean hasMethod(JvmDeclaredType type, JvmOperation op) {
		type.declaredOperations.exists[operationsEqual(it, op)]
	}
	
	def boolean hasMethod(XtendClass type, JvmOperation op) {
		type.members.filter(XtendFunction).exists[operationsEqual(it, op)]
	}

	def static boolean operationsEqual(XtendExecutable op1, JvmExecutable op2) {
		if (op1 instanceof XtendFunction && !(op2 instanceof JvmOperation)){
			return false
		}
		if (op1 instanceof XtendConstructor && !(op2 instanceof JvmConstructor))
			return false
		if (op1 instanceof XtendFunction){
			if ((op1 as XtendFunction).name != op2.simpleName)
				return false
		}
		if (op1.parameters.size != op2.parameters.size)
			return false

		for (i : 0 ..< op1.parameters.size) {
			val p1 = op1.parameters.get(i)
			val p2 = op2.parameters.get(i)
			if (p1.parameterType.qualifiedName != p2.parameterType.qualifiedName)
				return false
		}
		return true
	}

	def boolean operationsEqual(JvmOperation op1, JvmOperation op2) {
		if (op1.simpleName != op2.simpleName)
			return false
		if (op1.parameters.size != op2.parameters.size)
			return false
		if (op1.returnType != op2.returnType)
			return false
		for (i : 0 ..< op1.parameters.size) {
			val p1 = op1.parameters.get(i)
			val p2 = op2.parameters.get(i)
			if (p1.parameterType.qualifiedName != p2.parameterType.qualifiedName)
				return false
		}
		return true
	}
	
	def boolean operationsEqual(JvmOperation op1, Method op2){
		if (op1.simpleName != op2.name)
			return false
		if (op1.parameters.size != op2.parameterTypes.size)
			return false
		if (op1.returnType.qualifiedName != op2.returnType.canonicalName)
			return false
		for (i : 0 ..< op1.parameters.size) {
			val p1 = op1.parameters.get(i)
			val p2 = op2.parameterTypes.get(i)
			if (p1.parameterType.qualifiedName != p2.canonicalName)
				return false
		}
		return true
	}
	
	def getQualifiedName(XtendTypeDeclaration clazz){
		val file = clazz.eContainer as XtendFile
		return file.package + "." + clazz.name
	}
	
	def boolean isSubtypeOf(JvmDeclaredType t1, JvmDeclaredType t2){
		if (t1 == t2)
			return true
		val superTypes = t1.superTypes.map[type]
		if (superTypes.contains(t2))
			return true
		return superTypes.exists[(it as JvmDeclaredType).isSubtypeOf(t2)]
	}
}