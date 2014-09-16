package org.nanosite.xtendency.tracer.core;

import java.util.Map;

import org.eclipse.xtext.xbase.XExpression;
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext;

public interface ITracingProvider<T> {
	boolean canCreateTracePointFor(XExpression expr);
	
	String getId();
		
	void reset();
	
	TraceTreeNode<T> getRootNode();
	
	void enter(XExpression input, IEvaluationContext ctx);
	
	void exit(XExpression input, IEvaluationContext ctx, Object output);
	
	void skip(String output);
}
