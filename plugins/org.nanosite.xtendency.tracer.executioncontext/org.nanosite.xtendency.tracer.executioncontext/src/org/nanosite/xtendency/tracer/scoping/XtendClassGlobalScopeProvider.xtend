package org.nanosite.xtendency.tracer.scoping

import org.eclipse.xtext.common.types.xtext.TypesAwareDefaultGlobalScopeProvider
import javax.inject.Inject
import org.eclipse.xtext.scoping.IScope
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.EClass
import com.google.common.base.Predicate
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtend.core.xtend.XtendPackage
import org.nanosite.xtendency.tracer.tracingExecutionContext.ExecutionContext
import java.util.HashSet
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.emf.common.util.URI
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtext.scoping.Scopes
import java.util.ArrayList
import org.eclipse.xtext.naming.QualifiedName
import java.util.Set
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.resources.IContainer
import org.eclipse.core.resources.IFile
import org.eclipse.xtext.ui.resource.IResourceSetProvider

class XtendClassGlobalScopeProvider extends TypesAwareDefaultGlobalScopeProvider {
	
	@Inject
	IResourceSetProvider rsProvider
	
	override protected getScope(IScope parent, Resource context, boolean ignoreCase, EClass type, Predicate<IEObjectDescription> filter) {
		if (type == XtendPackage.eINSTANCE.xtendTypeDeclaration){
			val tec = context.contents.findFirst[it instanceof ExecutionContext] as  ExecutionContext
			if (tec != null && tec.projectName != null){
				val project = ResourcesPlugin.getWorkspace.root.getProject(tec.projectName)
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