package org.nanosite.xtendency.tracer.core;

import java.util.HashMap;
import java.util.Map;

import org.eclipse.xtext.naming.QualifiedName;
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext;
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationContext;
import org.eclipse.xtext.xbase.interpreter.impl.NullEvaluationContext;

import com.google.common.collect.Maps;

public class ChattyEvaluationContext implements IExtendedEvaluationContext{
	private IEvaluationContext parent;
	private Map<QualifiedName, Object> values = new HashMap<QualifiedName, Object>();
	
	public ChattyEvaluationContext() {
		this(new NullEvaluationContext());
	}
	
	public ChattyEvaluationContext(IEvaluationContext parent) {
		this.parent = parent;
	}

	public Object getValue(QualifiedName qualifiedName) {
		if (values != null && values.containsKey(qualifiedName))
			return values.get(qualifiedName);
		return parent.getValue(qualifiedName);
	}

	public void newValue(QualifiedName qualifiedName, Object value) {
		if (values == null)
			values = Maps.newHashMap();
		if (values.containsKey(qualifiedName))
			throw new IllegalStateException("Cannot create a duplicate value '" + qualifiedName + "'.");
		values.put(qualifiedName, value);
	}
	
	public void assignValue(QualifiedName qualifiedName, Object value) {
		if (values == null || !values.containsKey(qualifiedName))
			parent.assignValue(qualifiedName, value);
		else
			values.put(qualifiedName, value);
	}

	public IExtendedEvaluationContext fork() {
		return new ChattyEvaluationContext(this);
	}
	
	public Map<String, Object> getContents(){
		Map<String, Object> result = new HashMap<String, Object>();
		if (parent instanceof ChattyEvaluationContext){
			result.putAll(((ChattyEvaluationContext)parent).getContents());
		}
		for (QualifiedName k : values.keySet()){
			result.put(k.toString(), values.get(k));
		}
		return result;
	}

	@Override
	public IEvaluationContext getParent() {
		return parent;
	}
}
