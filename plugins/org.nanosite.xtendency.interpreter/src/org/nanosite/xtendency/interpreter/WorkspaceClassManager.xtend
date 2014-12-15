package org.nanosite.xtendency.interpreter

import com.google.inject.Inject
import org.eclipse.core.resources.IContainer
import org.eclipse.core.resources.IFile
import org.eclipse.emf.common.util.URI
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtext.ui.resource.IResourceSetProvider
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.core.resources.IFolder
import org.eclipse.jdt.core.IJavaProject
import org.eclipse.jdt.launching.JavaRuntime
import org.eclipse.core.runtime.Path
import java.net.URLClassLoader
import com.google.common.collect.HashBiMap
import java.util.HashMap
import com.google.common.collect.BiMap
import java.util.Map
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtend.core.xtend.AnonymousClass

class WorkspaceClassManager implements IClassManager{
	
	@Inject
	protected IResourceSetProvider rsProvider
	
	protected ResourceSet rs

	protected IContainer baseDir
	
	protected IJavaProject jp
	
	protected BiMap<IFile, URI> usedClasses = HashBiMap.create
	protected Map<String, Pair<IFile, URI>> availableClasses = new HashMap<String, Pair<IFile, URI>>
	protected Map<String, AnonymousClass> anonymousClasses = new HashMap

	protected ClassLoader classLoader

	@Deprecated
	def void addClassesInContainerWithPreloading(IContainer container) {
		rs = rsProvider.get(container.project)
		this.baseDir = container
		for (f : container.members.filter(IFile).filter[name.endsWith(".xtend")]) {
			val uri = URI.createPlatformResourceURI(f.fullPath.toString, true)
			try {
				val r = rs.getResource(uri, true)
				val file = r.contents.head
				if (file instanceof XtendFile) {
					for (type : file.xtendTypes) {
						val name = file.package + "." + type.name
						availableClasses.put(name, f -> uri)
					}
				}
			} catch (Exception e) {
				// ignore
			}
		}
		container.members.filter(IContainer).forEach[addClassesInContainerWithPreloading]
	}
	
	def void addClassesInContainer(IContainer container, IFile entryClassFile, XtendTypeDeclaration entryClass){
		rs = rsProvider.get(container.project)
		val file = entryClass.eContainer as XtendFile
		val packages = file.package.split('''\.''')
		var Iterable<String> curPkg = packages.reverse
		var curContainer = entryClassFile.parent
		while (curContainer != container){
			if (curContainer.name != curPkg.head)
				throw new IllegalStateException("Package " + curPkg.head + " is located in directory " + curContainer.name)
			curPkg = curPkg.tail
			curContainer = curContainer.parent
		}
		
		doAddClasses(curContainer, curPkg.toList.reverse.reduce[p1, p2 | p1 + "." + p2])
	}
	
	def void doAddClasses(IContainer container, String packagePrefix){
		for (f : container.members.filter(IFile).filter[name.endsWith(".xtend")]) {
			val uri = URI.createPlatformResourceURI(f.fullPath.toString, true)
			val className = packagePrefix + "." + f.name.substring(0, f.name.length - 6)
			availableClasses.put(className, f-> uri )
		}
		
		for (d : container.members.filter(IFolder)){
			doAddClasses(d, packagePrefix + "." + d.name)
		}
	}
	
	override recordClassUse(String fqn) {
		val locationInfo = availableClasses.get(fqn)
		usedClasses.put(locationInfo.key, locationInfo.value)
	}
	
	override canInterpretClass(String fqn) {
		availableClasses.containsKey(fqn) || anonymousClasses.containsKey(fqn)
	}
	
	override getClassUri(String fqn) {
		availableClasses.get(fqn).value
	}
	
	def getUsedClasses() {
		return usedClasses
	}
	
	override getResourceSet() {
		rs
	}
	
	override configureClassLoading(ClassLoader injectedClassLoader) {
		if (injectedClassLoader != null) {
			val classPathEntries = JavaRuntime.computeDefaultRuntimeClassPath(jp)
			val classPathUrls = classPathEntries.map[new Path(it).toFile().toURI().toURL()]

			var ClassLoader parent = injectedClassLoader
			parent = new DelegatorClassLoader(parent, XtendInterpreter, classPathUrls.map[toString])

			classLoader = new URLClassLoader(classPathUrls, parent)
			return classLoader
		}
		null
	}
	
	def setJavaProject(IJavaProject jp){
		this.jp = jp
	}

	override getConfiguredClassLoader(){
		classLoader
	}
	
	override getClassForName(String fqn) {
		if (anonymousClasses.containsKey(fqn))
			return anonymousClasses.get(fqn)
		val uri = getClassUri(fqn)
		val r = rs.getResource(uri, true)
		val file = r.contents.head as XtendFile
		file.xtendTypes.findFirst[c | file.package + "." + c.name == fqn]
	}
	
	override addAnonymousClass(String name, AnonymousClass classDef) {
		anonymousClasses.put(name, classDef)
	}
	
}
