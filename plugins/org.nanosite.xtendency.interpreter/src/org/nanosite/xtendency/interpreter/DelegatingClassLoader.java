package org.nanosite.xtendency.interpreter;

public class DelegatingClassLoader extends ClassLoader {
	private ClassLoader delegate;
	
	public DelegatingClassLoader(ClassLoader parent, ClassLoader delegate){
		super(parent);
		this.delegate = delegate;
	}
	
	@Override
	protected Class<?> findClass(String name) throws ClassNotFoundException {
		return delegate.loadClass(name);
	}
}
