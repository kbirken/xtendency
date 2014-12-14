package org.nanosite.xtendency.interpreter;

import java.security.SecureClassLoader;
import java.util.ArrayList;
import java.util.List;

import org.osgi.framework.Bundle;
import org.osgi.framework.BundleContext;
import org.osgi.framework.FrameworkUtil;
import org.osgi.framework.wiring.BundleWiring;

public class DelegatorClassLoader extends SecureClassLoader {
	private ClassLoader parent;
	private List<ClassLoader> delegates = new ArrayList<ClassLoader>();
	
	public DelegatorClassLoader(ClassLoader parent, Class<?> classInBundle, List<String> classPathUrls){
		this(parent, FrameworkUtil.getBundle(classInBundle).getBundleContext(), classPathUrls);
	}

	private DelegatorClassLoader(ClassLoader parent, BundleContext context, List<String> classPathUrls) {
		super(parent);
		
		this.parent = parent;
		for (String url : classPathUrls){
			Bundle b = context.getBundle("reference:" + url);
			if (b != null){
				ClassLoader newClassLoader = b.adapt(BundleWiring.class).getClassLoader();
				if (newClassLoader != null)
					delegates.add(newClassLoader);
			}
		}
	}
	
	public DelegatorClassLoader(ClassLoader parent){
		super(parent);
		Bundle[] bundles = FrameworkUtil.getBundle(getClass()).getBundleContext().getBundles();
		for (Bundle b : bundles){
			ClassLoader cl = b.adapt(BundleWiring.class).getClassLoader();
			if (cl != null){
				delegates.add(cl);
			}
		}
	}
	
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
