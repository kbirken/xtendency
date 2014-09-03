package org.nanosite.xtendency.tracer.scoping

import org.eclipse.xtext.common.types.xtext.TypesAwareDefaultGlobalScopeProvider
import org.eclipse.xtext.scoping.IScope
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.EClass
import com.google.common.base.Predicate
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.xtend.core.xtend.XtendPackage
import org.nanosite.xtendency.tracer.runConf.RunConfiguration
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.resources.IFile
import java.util.Set
import org.eclipse.core.resources.IProject
import org.eclipse.core.resources.IResource
import org.eclipse.core.resources.IFolder
import java.util.HashSet
import org.eclipse.core.resources.IContainer
import com.google.inject.Inject
import org.eclipse.xtext.ui.resource.IResourceSetProvider
import org.eclipse.emf.common.util.URI
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtext.scoping.Scopes
import org.eclipse.xtext.util.SimpleAttributeResolver
import org.eclipse.xtext.naming.QualifiedName
import java.util.ArrayList

class XtendClassGlobalScopeProvider extends TypesAwareDefaultGlobalScopeProvider {
	
	@Inject
	IResourceSetProvider rsProvider
	
	override protected getScope(IScope parent, Resource context, boolean ignoreCase, EClass type, Predicate<IEObjectDescription> filter) {
		if (type == XtendPackage.eINSTANCE.xtendTypeDeclaration){
			println("looking for xtendtype")
			println("context is " + context)
			val rconf = context.contents.findFirst[it instanceof RunConfiguration] as RunConfiguration
			if (rconf != null && rconf.projectName != null){
				val project = ResourcesPlugin.getWorkspace.root.getProject(rconf.projectName)
				if (project != null){
					val rs = rsProvider.get(project)
					val result = new HashSet<XtendTypeDeclaration>
					for (f : project.xtendFiles){
						val uri = URI.createPlatformResourceURI(f.fullPath.toString, true)
						val r = rs.getResource(uri, true)
						if (r.contents.head instanceof XtendFile){
							result += (r.contents.head as XtendFile).xtendTypes
						}
					}
					return Scopes.scopeFor(result, [t | 
						val package = (t.eContainer as XtendFile).package
						val packageSegments = new ArrayList<String>(package.split("\\."))
						packageSegments.add(t.name)
						QualifiedName.create(packageSegments)
					], parent)
				}
			}
		}else{
			super.getScope(parent, context, ignoreCase, type, filter)
		}
	}
	
	def protected dispatch Set<IFile> getXtendFiles(IContainer c){
		val result = new HashSet<IFile>
		result += c.members.map[getXtendFiles].flatten
		return result
	}
	
	def protected dispatch Set<IFile> getXtendFiles(IFile f){
		if (f.fileExtension == "xtend")
			return #{f}
		else
			return #{}
	}
	
}