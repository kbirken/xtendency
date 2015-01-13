package org.nanosite.xtendency.interpreter;

public class NullClassLoader extends ClassLoader {
	private ClassLoader parent;

	public NullClassLoader(ClassLoader parent) {
		super(parent);
		this.parent = parent;
	}

	protected Class<?> loadClass(String name, boolean resolve)
			throws ClassNotFoundException {
		synchronized (getClassLoadingLock(name)) {
			// First, check if the class has already been loaded
			Class c = null;
			try {
				c = parent.loadClass(name);
			} catch (ClassNotFoundException e) {
				// ClassNotFoundException thrown if class not found
				// from the non-null parent class loader
			}

			if (c == null) {
				// If still not found, then invoke findClass in order
				// to find the class.
				c = findClass(name);

			}
			if (resolve) {
				resolveClass(c);
			}
			return c;
		}
	}
}
