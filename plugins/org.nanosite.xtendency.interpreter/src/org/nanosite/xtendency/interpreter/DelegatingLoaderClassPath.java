package org.nanosite.xtendency.interpreter;

import java.io.InputStream;
import java.net.URL;

import javassist.LoaderClassPath;

public class DelegatingLoaderClassPath extends LoaderClassPath {
	private ClassLoader cl;

	public DelegatingLoaderClassPath(ClassLoader cl) {
		super(cl);
		this.cl = cl;
	}
	
	@Override
	public URL find(String classname) {
		Class<?> clazz;
		try {
			clazz = cl.loadClass(classname);
			ClassLoader loader = clazz.getClassLoader();
			String cname = classname.replace('.', '/') + ".class";
			return loader.getResource(cname);
		} catch (ClassNotFoundException e) {
			return super.find(classname);
		}	
	}
	
	@Override
	public InputStream openClassfile(String classname) {
		Class<?> clazz;
		try {
			clazz = cl.loadClass(classname);
			ClassLoader loader = clazz.getClassLoader();
			String cname = classname.replace('.', '/') + ".class";
			return loader.getResourceAsStream(cname);
		} catch (ClassNotFoundException e) {
			return super.openClassfile(classname);
		}	
	}

}
