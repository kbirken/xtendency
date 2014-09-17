package org.nanosite.xtendency.tracer.core.util

import com.google.inject.Inject
import java.io.File
import java.io.IOException
import java.util.Collections
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtend.core.xtend.XtendFile

class XtendHelpers {

	@Inject ResourceSetImpl resourceSet
//	@Inject XtextResourceSetProvider resourceSetProvider

	
	/** Load Xtend program from file (with given ResourceSet). */
	def load (String filename) {
		try {
			val fileURI = URI::createURI(filename)
			val resource = resourceSet.getResource(fileURI, true)
			resource.load(Collections::EMPTY_MAP)
			val f = resource.contents.get(0) as XtendFile
			EcoreUtil::resolveAll(f)
			return f
		} catch (IOException e) {
			e.printStackTrace()
			return null
		}
	}

	def Resource createResource (ResourceSet rset, XtendFile model, String filename) {
//		val resourceSet = resourceSetProvider.get()
		val fileUri = URI::createFileURI(new File(filename).getAbsolutePath)
		val res = rset.createResource(fileUri)
		res.getContents().add(model)
		return res
	}

	def save (Resource res) {
		println("creating derived state for resource")
//		res.installDerivedState(false) TODO
		try {
			println("saving resource")
			res.save(Collections::EMPTY_MAP)
	        println("Created Xtend file " + res.getURI.toFileString)
		} catch (IOException e) {
			e.printStackTrace
			return false
		}
		return true
	}
	
}