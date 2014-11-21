package org.nanosite.xtendency.tracer.core

import java.io.BufferedReader
import java.io.PrintWriter
import java.io.StringReader
import java.io.StringWriter
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import java.util.Stack
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.core.xtend.XtendClass
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtext.common.types.JvmExecutable
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.XMemberFeatureCall
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationResult
import org.eclipse.xtext.xbase.interpreter.impl.EvaluationException
import org.eclipse.xtext.xbase.interpreter.impl.InterpreterCanceledException

/*
 * Just added the tracing for rich strings for now, should be fused with the existing tracing mechanism.
 */
class TracingInterpreter extends XtendInterpreter {
	
	Set<ITracingProvider<?>> tracingProviders = new HashSet<ITracingProvider<?>>
	
	Stack<XAbstractFeatureCall> currentStackTrace = new Stack<XAbstractFeatureCall>
		
	override Object doEvaluate(XExpression expr, IEvaluationContext context, CancelIndicator indicator){
		doEvaluate(expr, context, indicator, true)
	}
	
	def Object doEvaluate(XExpression expr, IEvaluationContext context, CancelIndicator indicator, boolean trace){
		if (trace)
			tracingProviders.filter[canCreateTracePointFor(expr)].forEach[enter(expr, context)]
		val Map<String, Object> ctx = new HashMap<String, Object>
		val result = super.doEvaluate(expr, context, indicator)
		if (trace)
			tracingProviders.filter[canCreateTracePointFor(expr)].forEach[
				exit(expr, context, result)
			]
		return result
	}
	
	def void addTracingProvider(ITracingProvider tp){
		tracingProviders += tp
	}
	
	override def IRichStringExecutor createRichStringExecutor(IEvaluationContext context, CancelIndicator indicator) {
		new TracingRichStringExecutor(this, context, indicator, tracingProviders)
	}
	
	def getTraces(String tracingProviderId) {
		val tp = tracingProviders.findFirst[id == tracingProviderId] 
		tp.rootNode
	}

	def void reset() {
		tracingProviders.forEach[reset]
	}
	
	override protected _doEvaluate(XAbstractFeatureCall featureCall, IEvaluationContext context, CancelIndicator indicator) {
		var Object before = null
		if (featureCall.feature instanceof JvmExecutable){
			if (!currentStackTrace.empty())
				before = currentStackTrace.peek
			println("pushing " + currentStackTrace.size)
			currentStackTrace.push(featureCall)
		}
		val result = super._doEvaluate(featureCall, context, indicator)
		if (featureCall.feature instanceof JvmExecutable){
			println("popping " + currentStackTrace.size)
			currentStackTrace.pop
			
			// maybe something bad happened in the meantime? like a thrown and caught exception?
			// in which case there may be other stuff on the stack now? and we should remove it
			// actually this seems to cause problems with recursive calls??
			while (!currentStackTrace.empty() && before != null && currentStackTrace.peek != before){
				println("popping " + currentStackTrace.size)			
				currentStackTrace.pop
			}
		}
		return result
	}
	
	override protected _doEvaluate(XMemberFeatureCall featureCall, IEvaluationContext context, CancelIndicator indicator) {
		if (featureCall.feature instanceof JvmExecutable){
			println("pushing " + currentStackTrace.size)
			currentStackTrace.push(featureCall)
		}
		val result = super._doEvaluate(featureCall, context, indicator)
		if (featureCall.feature instanceof JvmExecutable){
			println("popping " + currentStackTrace.size)
			currentStackTrace.pop
		}
		return result
	}
	
	override evaluate(XExpression expression, IEvaluationContext context, CancelIndicator indicator) {
		println("clearing " + currentStackTrace.size)
		currentStackTrace.clear
		try {
			val result = internalEvaluate(expression, context, if (indicator!=null) indicator else CancelIndicator.NullImpl);
			return new DefaultEvaluationResult(result, null);
		} catch (EvaluationException e) {
			val nl = System.getProperty("line.separator", "\n")
			val result = new StringBuilder
			val sw = new StringWriter()
			val pw = new PrintWriter(sw)
			e.cause.printStackTrace(pw)
			
			val br = new BufferedReader(new StringReader(sw.toString))
			var continueReading = true
			while (continueReading){
				val current = br.readLine
				if (current == null 
					|| current.contains("sun.reflect.NativeMethodAccessor") 
					|| current.contains("sun.reflect.GeneratedMethodAccessor")
					|| current.contains("org.nanosite.xtendency.tracer.core.")
					|| current.contains("org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter"))
					continueReading = false
				else 
					result.append(current).append(nl)
			}
			
			val stackInOrder = currentStackTrace.reverse
			for (call : stackInOrder){
				val op = call.getParent(XtendFunction)
				val clazz = op?.getParent(XtendClass)
				val file = clazz?.getParent(XtendFile)
				if (file != null){
					val opName =  file.package + "." + clazz.name + "." + op.name
					val filename = call.eResource.URI.lastSegment
					val node = NodeModelUtils.findActualNodeFor(call)
					result.append("\tat " + opName+ "(" + filename + ":" + node.startLine + ")").append(nl)
				}
			}
			return new XtendEvaluationResult(null, e.getCause(), result.toString);
		} catch (InterpreterCanceledException e) {
			return null;
		}catch (Exception e){
			if (e.class.simpleName == "ReturnValue"){
				val rvField = e.class.getDeclaredField("returnValue")
				rvField.accessible = true
				return new DefaultEvaluationResult(rvField.get(e), null)
			}else{
				throw e
			}
				
		}
	}
	
	def protected <T> T getParent(EObject eo, Class<T> clazz){
		if (clazz.isInstance(eo)){
			return eo as T
		}else{
			eo.eContainer?.getParent(clazz)
		}
	}
}
