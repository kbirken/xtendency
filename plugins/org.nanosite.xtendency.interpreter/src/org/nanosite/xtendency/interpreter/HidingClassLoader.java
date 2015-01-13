package org.nanosite.xtendency.interpreter;

import java.util.HashSet;
import java.util.Set;

public class HidingClassLoader extends ClassLoader {
	private Set<String> toHide = new HashSet<String>();
	private ClassLoader parent;
	
	public HidingClassLoader(ClassLoader parent){
		super(parent);
		this.parent = parent;
	}
	
	@Override
	public Class<?> loadClass(String name) throws ClassNotFoundException {
		if (toHide.contains(name))
			throw new ClassNotFoundException();
		else
			return super.loadClass(name);
	}
	
	public void hideClass(String name){
		toHide.add(name);
	}
	
	public void hideClasses(Set<String> names){
		toHide.addAll(names);
	}
	
}
