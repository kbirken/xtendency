package org.nanosite.xtendency.tracer.core;

import java.security.SecureClassLoader;
import java.util.ArrayList;
import java.util.List;

import org.osgi.framework.Bundle;
import org.osgi.framework.BundleContext;
import org.osgi.framework.wiring.BundleWiring;

public class DelegatorClassLoader extends SecureClassLoader {
	private ClassLoader parent;
	private List<ClassLoader> delegates = new ArrayList<ClassLoader>();

	public DelegatorClassLoader(ClassLoader parent, BundleContext context, List<String> classPathUrls) {
		super(parent);
		this.parent = parent;
		for (String url : classPathUrls){
			Bundle b = context.getBundle("reference:" + url);
			if (b != null){
				delegates.add(b.adapt(BundleWiring.class).getClassLoader());
			}
		}
	}
/*
	@Override
	protected synchronized Class<?> loadClass(String name, boolean resolve)
			throws ClassNotFoundException {
		Class<?> result = null;
		if (delegate != null) {
			try {
				delegate.loadClass(name);
			} catch (ClassNotFoundException e) {
				System.out.println("not found in delegate");
			}
		}
		if (result == null) {
			parent.loadClass(name);
		}
		return result;
	}*/
	
	@Override
	protected Class<?> findClass(String name) throws ClassNotFoundException {
		for (ClassLoader d : delegates){
			try{
				return d.loadClass(name);
			}catch(ClassNotFoundException e){
				// do nothing, try next
			}
		}
		throw new ClassNotFoundException(name);
	}
}
