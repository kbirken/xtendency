package org.nanosite.xtendency.tracer.jvmmodel

import com.google.inject.Inject
import org.eclipse.xtext.xbase.jvmmodel.AbstractModelInferrer
import org.eclipse.xtext.xbase.jvmmodel.IJvmDeclaredTypeAcceptor
import org.eclipse.xtext.xbase.jvmmodel.JvmTypesBuilder
import org.nanosite.xtendency.tracer.tracingExecutionContext.ExecutionContext
import org.eclipse.xtext.common.types.JvmTypeReference
import org.eclipse.xtend.core.xtend.XtendFile
import com.google.inject.Injector
import org.eclipse.xtext.common.types.JvmParameterizedTypeReference

/**
 * <p>Infers a JVM model from the source model.</p> 
 *
 * <p>The JVM model should contain all elements that would appear in the Java code 
 * which is generated from the source model. Other models link against the JVM model rather than the source model.</p>     
 */
class TracingExecutionContextJvmModelInferrer extends AbstractModelInferrer {

	/**
     * convenience API to build and initialize JVM types and their members.
     */
	@Inject extension JvmTypesBuilder

	/**
	 * The dispatch method {@code infer} is called for each instance of the
	 * given element's type that is contained in a resource.
	 * 
	 * @param element
	 *            the model to create one or more
	 *            {@link org.eclipse.xtext.common.types.JvmDeclaredType declared
	 *            types} from.
	 * @param acceptor
	 *            each created
	 *            {@link org.eclipse.xtext.common.types.JvmDeclaredType type}
	 *            without a container should be passed to the acceptor in order
	 *            get attached to the current resource. The acceptor's
	 *            {@link IJvmDeclaredTypeAcceptor#accept(org.eclipse.xtext.common.types.JvmDeclaredType)
	 *            accept(..)} method takes the constructed empty type for the
	 *            pre-indexing phase. This one is further initialized in the
	 *            indexing phase using the closure you pass to the returned
	 *            {@link org.eclipse.xtext.xbase.jvmmodel.IJvmDeclaredTypeAcceptor.IPostIndexingInitializing#initializeLater(org.eclipse.xtext.xbase.lib.Procedures.Procedure1)
	 *            initializeLater(..)}.
	 * @param isPreIndexingPhase
	 *            whether the method is called in a pre-indexing phase, i.e.
	 *            when the global index is not yet fully updated. You must not
	 *            rely on linking using the index if isPreIndexingPhase is
	 *            <code>true</code>.
	 */
	def dispatch void infer(ExecutionContext element, IJvmDeclaredTypeAcceptor acceptor, boolean isPreIndexingPhase) {

		if (element != null && element.inits != null && element.clazz != null) {
			val className = (element.clazz.eContainer as XtendFile).package + "." + element.name
			acceptor.accept(element.toClass(className)).initializeLater [
				if (element.injector != null) {
					members += element.injector.toMethod("getInjector", element.injector.newTypeRef(Injector),
						[
							body = element.injector
						])
				}
				for (i : element.inits) {
					members += i.toMethod("initialize" + i.param.toFirstUpper, i.param.getTypeForParam(element),
						[
							for (f : element.injectedMembers){
								parameters += f.toParameter(f.name, f.type)
							}
							body = i.expr
						])
				}
			]
		}
	}

	def JvmTypeReference getTypeForParam(String name, ExecutionContext ec) {
		if (ec.function?.parameters?.findFirst[it.name == name]?.parameterType != null){
			val type = ec.function.parameters.findFirst[it.name == name].parameterType
			return type.copy(ec)
		} 
		return ec.newTypeRef(Object)
	}
	
	def dispatch JvmTypeReference copy(JvmTypeReference ref, ExecutionContext ec) {
		return ec.newTypeRef(ref.type.qualifiedName)
	}
	
	def dispatch JvmTypeReference copy(JvmParameterizedTypeReference ref, ExecutionContext ec){
		return ec.newTypeRef(ref.type.qualifiedName, ref.arguments.map[copy(ec)])
	}
}

