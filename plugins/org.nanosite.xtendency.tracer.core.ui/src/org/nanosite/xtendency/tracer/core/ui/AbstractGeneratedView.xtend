package org.nanosite.xtendency.tracer.core.ui

import org.eclipse.ui.part.ViewPart
import org.eclipse.ui.ISelectionListener
import org.eclipse.core.resources.IResourceChangeListener
import org.eclipse.core.resources.IFile
import org.eclipse.xtext.xbase.XExpression
import com.google.inject.Inject
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.nanosite.xtendency.tracer.core.TracingInterpreter
import org.eclipse.xtext.ui.resource.IResourceSetProvider
import org.eclipse.core.resources.IWorkspace
import org.eclipse.core.runtime.jobs.ISchedulingRule
import org.eclipse.ui.progress.UIJob
import org.eclipse.core.runtime.IStatus
import org.eclipse.core.runtime.IProgressMonitor
import org.eclipse.xtext.ui.views.DefaultWorkbenchPartSelection
import org.eclipse.core.runtime.Status
import org.eclipse.xtext.ui.editor.SchedulingRuleFactory
import org.eclipse.xtend.ide.internal.XtendActivator
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.nanosite.xtendency.tracer.tracingExecutionContext.ExecutionContext
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.core.runtime.Path
import com.google.inject.Injector
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.emf.common.util.URI
import org.eclipse.xtext.ui.views.IWorkbenchPartSelection
import org.eclipse.jface.text.TextSelection
import org.eclipse.jdt.core.JavaCore
import org.eclipse.core.resources.IResourceDelta
import java.util.Set
import org.eclipse.core.resources.IResourceChangeEvent
import java.util.Collections
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.core.resources.IProject
import org.nanosite.xtendency.tracer.core.ChattyEvaluationContext
import org.eclipse.ui.IPartListener2
import org.eclipse.ui.IWorkbenchPartReference
import org.eclipse.swt.widgets.Composite

abstract class AbstractGeneratedView extends ViewPart implements IGeneratedView, IResourceChangeListener, ISelectionListener, IPartListener2 {
	protected static final ISchedulingRule SEQUENCE_RULE = SchedulingRuleFactory.INSTANCE.newSequence();
	
	protected IFile tecFile
	protected XExpression inputExpression

	protected IEvaluationContext initialContext
	
	@Inject
	protected TracingInterpreter interpreter

	@Inject
	protected IResourceSetProvider rsProvider;

	@Inject
	protected IWorkspace workspace;
	
	protected RefreshJob refreshJob = new RefreshJob(SEQUENCE_RULE, this);
	
	new() {
		XtendActivator.getInstance().getInjector(XtendActivator.ORG_ECLIPSE_XTEND_CORE_XTEND).injectMembers(this);
	}
	
	def setInput(XtendTypeDeclaration typeDecl, XExpression inputExpression, IEvaluationContext context, IFile file) {
		interpreter.setCurrentType(typeDecl, file)
		this.inputExpression = inputExpression
		this.initialContext = context
	}

	def setInput(ExecutionContext ec, IFile tecFile) {
		workspace.addResourceChangeListener(this);
		val project = ResourcesPlugin.getWorkspace.root.getProject(ec.projectName)
		val urlClassLoader = interpreter.addProjectToClasspath(JavaCore.create(project))

		val f = ec.getClazz().eContainer() as XtendFile
		val file = getFileForUri(f.eResource.URI, tecFile.project)
		val typeDecl = ec.getClazz();
		val func = ec.getFunction();
		val inputExpression = func.getExpression();
		val context = new ChattyEvaluationContext();

		val Injector injector = if(ec.injector != null) interpreter.evaluate(ec.injector).result as Injector else null
		val initContext = new ChattyEvaluationContext()

		if (injector != null) {
			for (im : ec.injectedMembers) {
				val desiredClass = Class.forName(im.type.type.identifier, true, urlClassLoader)
				initContext.newValue(QualifiedName.create(im.name), injector.getInstance(desiredClass))
			}
		}

		for (i : ec.getInits()) {
			try {
				val result = interpreter.evaluate(i.getExpr(), initContext.fork, CancelIndicator.NullImpl);
				val value = result.getResult();
				if (result.exception == null) {
					context.newValue(QualifiedName.create(i.getParam()), value);
					if (injector != null && i.param == "this") {
						injector.injectMembers(value)
					}
				} else {
					println("Interpreter exception during evaluation of initializer '" + i.param + "':")
					result.exception.printStackTrace
				}
			} catch (Exception e) {
				e.printStackTrace
			}
		}
		interpreter.configure(file.parent)
		setInput(typeDecl, inputExpression, context, file)
		this.tecFile = tecFile
		refreshJob.reschedule();
	}
	
	def void doCreatePartControl(Composite parent)
	
	override createPartControl(Composite parent) {
		parent.doCreatePartControl
		getSite().getWorkbenchWindow().getPartService().addPartListener(this);
	}

	private def String dropFirstSegment(URI uri) {
		val sb = new StringBuilder();
		val firstSegment = if (uri.segment(0) == "resource") 2 else 1
		for (var i = firstSegment; i < uri.segmentCount(); i++) {
			sb.append("/");
			val curSeg = uri.segment(i)
			sb.append(curSeg);
		}
		return sb.toString();
	}
	
	//TODO: clean up this mess
	override public void resourceChanged(IResourceChangeEvent event) {
		val usedFiles = interpreter.usedClasses
		val changedInput = event.delta.concernsFile(usedFiles.keySet)
		if (event.delta != null && changedInput != null) {
			val rs = rsProvider.get(tecFile.getProject())
			val r = rs.getResource(URI.createURI(tecFile.getFullPath().toString()), true)
			val classResource = rs.getResource(usedFiles.get(changedInput), true)
			classResource.unload
			r.unload
			r.load(Collections.EMPTY_MAP)
			EcoreUtil.resolveAll(r)
			val ec = r.contents.head as ExecutionContext
			setInput(ec, tecFile)
			refreshJob.reschedule();
		} else if (event.delta != null && tecFile != null && event.delta.concernsFile(tecFile)) {
			val rs = rsProvider.get(tecFile.getProject())
			val r = rs.getResource(URI.createURI(tecFile.getFullPath().toString()), true)
			val classResource = inputExpression.eResource
			classResource.unload
			r.unload
			r.load(Collections.EMPTY_MAP)
			EcoreUtil.resolveAll(r)
			val ec = r.contents.head as ExecutionContext
			setInput(ec, tecFile)
			refreshJob.reschedule();
		}
	}

	def protected boolean concernsFile(IResourceDelta delta, IFile file) {
		if (delta == null) {
			return false
		}
		if (file == null) {
			return false
		}
		if (delta.fullPath == file.fullPath)
			return true
		return delta.affectedChildren.exists[concernsFile(file)]
	}

	def protected IFile concernsFile(IResourceDelta delta, Set<IFile> files) {
		for (f : files) {
			if (delta.concernsFile(f)) {
				return f
			}
		}
		return null
	}
	
	def protected void computeAndSetInput(IWorkbenchPartSelection selection)
	
	def IFile getFileForUri(URI uri, IProject project){
		val filePath = dropFirstSegment(uri);
		val file = project.getFile(Path.fromPortableString(filePath));
		file
	}
	
	def URI getUriForFile(IFile file){
		throw new UnsupportedOperationException
	}
	
	override partClosed(IWorkbenchPartReference partRef) {
	}
	
	override partDeactivated(IWorkbenchPartReference partRef) {
	}
	
	override partHidden(IWorkbenchPartReference partRef) {
	}
	
	override partInputChanged(IWorkbenchPartReference partRef) {
	}
	
	override partOpened(IWorkbenchPartReference partRef) {
	}
	
	override partActivated(IWorkbenchPartReference partRef) {
	}
	
	override partBroughtToTop(IWorkbenchPartReference partRef) {
	}
	
	override partVisible(IWorkbenchPartReference partRef) {
	}
	
	protected static class RefreshJob extends UIJob {
		private AbstractGeneratedView view

		new(ISchedulingRule schedulingRule, AbstractGeneratedView view) {
			super("TODO");
			this.view = view
			setRule(schedulingRule);
		}

		override public IStatus runInUIThread(IProgressMonitor monitor) {
			view.computeAndSetInput(
				new DefaultWorkbenchPartSelection(view.getSite().getPage().getActivePart(),
					view.getSite().getPage().getSelection()));
			return Status.OK_STATUS;
		}

		def protected void reschedule() {
			cancel();
			schedule();
		}
	} 
}