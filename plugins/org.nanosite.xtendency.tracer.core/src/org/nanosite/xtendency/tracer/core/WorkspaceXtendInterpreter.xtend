package org.nanosite.xtendency.tracer.core

import com.google.inject.Inject
import org.eclipse.core.resources.IContainer
import org.eclipse.core.resources.IFile
import org.eclipse.emf.common.util.URI
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtext.ui.resource.IResourceSetProvider
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.core.resources.IFolder

class WorkspaceXtendInterpreter extends XtendInterpreter {
	
	@Inject
	protected IResourceSetProvider rsProvider

	protected IContainer baseDir

	@Deprecated
	def void addClassesInContainerWithPreloading(IContainer container) {
		this.rs = rsProvider.get(container.project)
		this.baseDir = container
		for (f : container.members.filter(IFile).filter[name.endsWith(".xtend")]) {
			val uri = URI.createURI(f.fullPath.toString, true)
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
		this.rs = rsProvider.get(container.project)
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
			val uri = URI.createURI(f.fullPath.toString, true)
			val className = packagePrefix + "." + f.name.substring(0, f.name.length - 6)
			availableClasses.put(className, f-> uri )
		}
		
		for (d : container.members.filter(IFolder)){
			doAddClasses(d, packagePrefix + "." + d.name)
		}
	}

}
