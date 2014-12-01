package org.nanosite.xtendency.interpreter;

import java.util.Map;

import org.eclipse.xtext.xbase.interpreter.IEvaluationContext;

public interface IExtendedEvaluationContext extends IEvaluationContext{
	IEvaluationContext getParent();
	Map<String, Object> getContents();
	public IExtendedEvaluationContext fork();
}
