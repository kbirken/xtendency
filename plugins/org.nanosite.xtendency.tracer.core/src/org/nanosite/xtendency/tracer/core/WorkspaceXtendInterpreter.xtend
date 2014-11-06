package org.nanosite.xtendency.tracer.core

import com.google.inject.Inject
import org.eclipse.core.resources.IContainer
import org.eclipse.core.resources.IFile
import org.eclipse.emf.common.util.URI
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtext.ui.resource.IResourceSetProvider

class WorkspaceXtendInterpreter extends XtendInterpreter {
	
	@Inject
	protected IResourceSetProvider rsProvider

	protected IContainer baseDir

	def void configure(IContainer container) {
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
		container.members.filter(IContainer).forEach[configure]
	}

}
