package org.nanosite.xtendency.tracer.richstring.ui

import com.google.inject.Inject
import java.util.Collections
import java.util.HashSet
import java.util.Set
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.IResourceChangeEvent
import org.eclipse.core.resources.IResourceChangeListener
import org.eclipse.core.resources.IResourceDelta
import org.eclipse.core.resources.IWorkspace
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.IProgressMonitor
import org.eclipse.core.runtime.IStatus
import org.eclipse.core.runtime.Path
import org.eclipse.core.runtime.Status
import org.eclipse.core.runtime.jobs.ISchedulingRule
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.jdt.core.JavaCore
import org.eclipse.jface.resource.ColorRegistry
import org.eclipse.jface.text.IDocument
import org.eclipse.jface.text.TextSelection
import org.eclipse.jface.text.source.Annotation
import org.eclipse.jface.text.source.AnnotationModel
import org.eclipse.jface.text.source.AnnotationRulerColumn
import org.eclipse.jface.text.source.CompositeRuler
import org.eclipse.jface.text.source.IOverviewRuler
import org.eclipse.jface.text.source.LineNumberRulerColumn
import org.eclipse.jface.text.source.OverviewRuler
import org.eclipse.jface.text.source.SourceViewer
import org.eclipse.jface.text.source.projection.ProjectionViewer
import org.eclipse.jface.util.PropertyChangeEvent
import org.eclipse.jface.viewers.ISelection
import org.eclipse.jface.viewers.ISelectionChangedListener
import org.eclipse.jface.viewers.SelectionChangedEvent
import org.eclipse.swt.SWT
import org.eclipse.swt.graphics.Color
import org.eclipse.swt.graphics.RGB
import org.eclipse.swt.widgets.Composite
import org.eclipse.swt.widgets.Display
import org.eclipse.ui.IWorkbenchPart
import org.eclipse.ui.IWorkbenchPartReference
import org.eclipse.ui.part.FileEditorInput
import org.eclipse.ui.progress.UIJob
import org.eclipse.ui.texteditor.DefaultMarkerAnnotationAccess
import org.eclipse.ui.texteditor.ResourceMarkerAnnotationModel
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.xtend.ide.internal.XtendActivator
import org.eclipse.xtend.ide.view.Messages
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.ui.editor.SchedulingRuleFactory
import org.eclipse.xtext.ui.editor.XtextEditor
import org.eclipse.xtext.ui.resource.IResourceSetProvider
import org.eclipse.xtext.ui.views.AbstractSourceView
import org.eclipse.xtext.ui.views.DefaultWorkbenchPartSelection
import org.eclipse.xtext.ui.views.IWorkbenchPartSelection
import org.eclipse.xtext.util.TextRegion
import org.eclipse.xtext.xbase.XAbstractFeatureCall
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationContext
import org.eclipse.xtext.xbase.ui.editor.XbaseEditor
import org.nanosite.xtendency.tracer.core.TraceTreeNode
import org.nanosite.xtendency.tracer.core.TracingInterpreter
import org.nanosite.xtendency.tracer.runConf.RunConfiguration

import static org.eclipse.jface.resource.JFaceResources.*
import static org.eclipse.ui.editors.text.EditorsUI.*
import org.nanosite.xtendency.tracer.richstring.RichStringTracingProvider
import org.nanosite.xtendency.tracer.richstring.RichStringOutputLocation
import com.google.inject.Injector
import org.eclipse.xtext.util.CancelIndicator

/**
 *
 * Heavily inspired by Xtend's DerivedSourceView by
 * @author Sven Efftinge - Initial contribution and API
 * @author Michael Clay
 */
public class DerivedSourceView extends AbstractSourceView implements IResourceChangeListener {
	protected static final int VERTICAL_RULER_WIDTH = 12;
	protected static final int OVERVIEW_RULER_WIDTH = 12;
	private static final ISchedulingRule SEQUENCE_RULE = SchedulingRuleFactory.INSTANCE.newSequence();
	
	private String lastInput = null;

	private static final Color COLOR_SELECTED = new Color(Display.getCurrent, 255, 0, 0)

	private IFile selectedFile

	private IFile rconfFile
	
	private int lastOffsetInEditor = -1
	private int lastLengthInEditor = -1
	private int lastOffsetInView = -1
	private int lastLengthInView = -1

	private XbaseEditor associatedEditor

	private XExpression inputExpression

	private IEvaluationContext initialContext

	@Inject
	private IWorkspace workspace;

	@Inject
	private ColorRegistry colorRegistry

	@Inject
	private TracingInterpreter interpreter

	@Inject
	private IResourceSetProvider rsProvider;

	private DefaultMarkerAnnotationAccess defaultMarkerAnnotationAccess = new DefaultMarkerAnnotationAccess();
	private DerivedSourceView.RefreshJob refreshJob = new DerivedSourceView.RefreshJob(SEQUENCE_RULE, this);

	private ProjectionViewer sourceViewer

	private long lastChange = System.currentTimeMillis

	new() {
		XtendActivator.getInstance().getInjector(XtendActivator.ORG_ECLIPSE_XTEND_CORE_XTEND).injectMembers(this);
		interpreter.addTracingProvider(new RichStringTracingProvider)
		colorRegistry.put("de.itemis.codegenutil.ui.DerivedSourceView.backgroundColor", new RGB(255, 255, 255))
	}

	override selectionChanged(IWorkbenchPart workbenchPart, ISelection selection) {
		if (workbenchPart instanceof XbaseEditor) {
			if (workbenchPart.editorInput instanceof FileEditorInput) {
				val fei = workbenchPart.editorInput as FileEditorInput
				if (fei.file == selectedFile) {
					if (associatedEditor == null)
						associatedEditor = workbenchPart
					if (selection instanceof TextSelection) {
						if (!(selection.offset == lastOffsetInEditor && selection.length == lastLengthInEditor))
							super.selectionChanged(workbenchPart, selection)
					}
				}
			}
		} else if (workbenchPart == this && associatedEditor != null && interpreter?.getTraces(RichStringTracingProvider.RICH_STRING_TRACING_PROVIDER_ID) != null) {
			if (selection instanceof TextSelection) {
				if (!(selection.offset == lastOffsetInView && selection.length == lastLengthInView)) {
					val nodes = new HashSet<TraceTreeNode<RichStringOutputLocation>>
					findRelevantNodesForOutput(interpreter.getTraces(RichStringTracingProvider.RICH_STRING_TRACING_PROVIDER_ID) as TraceTreeNode<RichStringOutputLocation>, nodes, selection.offset, selection.length)
					if (!nodes.empty) {
						var start = Integer.MAX_VALUE
						var end = Integer.MIN_VALUE
						for (n : nodes) {
							val node = NodeModelUtils.findActualNodeFor(n.input.expression)
							start = Math.min(start, node.offset)
							end = Math.max(end, node.offset + node.length)
						}
						val length = end - start

						lastOffsetInEditor = start
						lastLengthInEditor = length
						associatedEditor.selectAndReveal(start, length)
					}
				}
			}
		}
	}

	def setInput(XtendTypeDeclaration typeDecl, XExpression inputExpression, IEvaluationContext context, IFile file) {
		interpreter.currentType = typeDecl
		this.inputExpression = inputExpression
		this.initialContext = context
		this.selectedFile = file
	}

	def setInput(RunConfiguration rc, IFile rconfFile) {
		val project = ResourcesPlugin.getWorkspace.root.getProject(rc.projectName)
		val urlClassLoader = interpreter.addProjectToClasspath(JavaCore.create(project))

		val f = rc.getClazz().eContainer() as XtendFile
		val filePath = dropFirstSegment(f.eResource().getURI());
		val file = (rconfFile as IFile).getProject().getFile(Path.fromPortableString(filePath));
		val typeDecl = rc.getClazz();
		val func = rc.getFunction();
		val inputExpression = func.getExpression();
		val context = new DefaultEvaluationContext();

		val Injector injector = if (rc.injector != null) interpreter.evaluate(rc.injector).result as Injector else null
		val initContext = new DefaultEvaluationContext()
		
		if (injector != null){
			for (im : rc.injectedMembers){
				val desiredClass = Class.forName(im.type.type.identifier, true, urlClassLoader)
				initContext.newValue(QualifiedName.create(im.name), injector.getInstance(desiredClass))
			}
		}

		for (i : rc.getInits()) {
			val result = interpreter.evaluate(i.getExpr(), initContext.fork, CancelIndicator.NullImpl);
			val value = result.getResult();
			context.newValue(QualifiedName.create(i.getParam()), value);
			if (injector != null && i.param == "this"){
				injector.injectMembers(value)
			}
		}

		setInput(typeDecl, inputExpression, context, file)
		this.rconfFile = rconfFile
	}

	private def String dropFirstSegment(URI uri) {
		val sb = new StringBuilder();
		for (var i = 2; i < uri.segmentCount(); i++) {
			sb.append("/");
			sb.append(uri.segment(i));
		}
		return sb.toString();
	}

	override isIgnored(IWorkbenchPartSelection s) {
		return !(s.selection instanceof TextSelection)
	}

	override public void createPartControl(Composite parent) {
		super.createPartControl(parent);
	}

	override protected SourceViewer createSourceViewer(Composite parent) {
		val IOverviewRuler overviewRuler = new OverviewRuler(defaultMarkerAnnotationAccess, OVERVIEW_RULER_WIDTH,
			getSharedTextColors());
		val AnnotationRulerColumn annotationRulerColumn = new AnnotationRulerColumn(VERTICAL_RULER_WIDTH,
			defaultMarkerAnnotationAccess);

		annotationRulerColumn.addAnnotationType(Annotation.TYPE_UNKNOWN);
		val LineNumberRulerColumn lineNumberRuleColumn = new LineNumberRulerColumn();
		lineNumberRuleColumn.setBackground(Display.getDefault().getSystemColor(SWT.COLOR_WIDGET_BACKGROUND));
		lineNumberRuleColumn.setFont(getFont(getViewerFontName()));
		val CompositeRuler compositeRuler = new CompositeRuler();
		compositeRuler.addDecorator(0, annotationRulerColumn);
		compositeRuler.addDecorator(1, lineNumberRuleColumn);
		sourceViewer = new ProjectionViewer(parent, compositeRuler, overviewRuler, true,
			SWT.V_SCROLL.bitwiseOr(SWT.H_SCROLL));
		sourceViewer.editable = false
		val slf = this

		sourceViewer.addSelectionChangedListener(
			new ISelectionChangedListener() {

				override selectionChanged(SelectionChangedEvent event) {
					slf.selectionChanged(slf, event.selection)
				}

			})
		return sourceViewer;
	}

	override protected boolean isValidSelection(IWorkbenchPartSelection workbenchPartSelection) {
		return this.inputExpression != null && this.initialContext != null
	}

	override protected String getBackgroundColorKey() {
		return "de.itemis.codegenutil.ui.DerivedSourceView.backgroundColor"; //$NON-NLS-1$
	}

	override protected String getViewerFontName() {
		return "org.eclipse.xtend.ui.editors.textfont"; //$NON-NLS-1$
	}
	
	override protected computeInput(IWorkbenchPartSelection workbenchPartSelection) {
		if (lastInput == null){
			lastInput = doComputeInput(workbenchPartSelection);
		}
		return lastInput;
	}

	def protected String doComputeInput(IWorkbenchPartSelection workbenchPartSelection) {
		println("recomputing input")
		val interpResult = SynchronizedInterpreterAccess.evaluate(interpreter, inputExpression, initialContext.fork)
		if (interpResult.result != null && interpResult.result instanceof CharSequence) {
			return interpResult.result.toString
		} else {
			return interpResult.exception.toString
		}
	}

	def protected IFile getSelectedFile() {
		return selectedFile;
	}

	override public void propertyChange(PropertyChangeEvent event) {
		super.propertyChange(event);
		sourceViewer.invalidateTextPresentation();
	}

	override public void partVisible(IWorkbenchPartReference ref) {
		super.partVisible(ref);
		if (ref.getId().equals(getSite().getId())) {
			workspace.addResourceChangeListener(this);
		}
	}

	override public void partHidden(IWorkbenchPartReference workbenchPartReference) {
		super.partHidden(workbenchPartReference);
		if (workbenchPartReference.getId().equals(getSite().getId())) {
			workspace.removeResourceChangeListener(this);
		}
		if (getWorkbenchPartSelection() != null &&
			workbenchPartReference.getPart(false) == getWorkbenchPartSelection().getWorkbenchPart()) {
			setWorkbenchPartSelection(null);
			setContentDescription("");
			setInput("");
		}
	}

	//TODO: clean up this mess
	override public void resourceChanged(IResourceChangeEvent event) {
		lastInput = null;
		if (event.delta != null && event.delta.concernsFile(selectedFile)) {
			if (rconfFile == null) {
				val resource = inputExpression.eResource
				resource.unload
				resource.load(Collections.EMPTY_MAP)
				EcoreUtil.resolveAll(resource)
				inputExpression = ((resource.contents.head as XtendFile).xtendTypes.head.members.head as XtendFunction).
					expression
				interpreter.currentType = (resource.contents.head as XtendFile).xtendTypes.head
			} else {
				val rs = rsProvider.get(rconfFile.getProject())
				val r = rs.getResource(URI.createURI(rconfFile.getFullPath().toString()), true)
				val classResource = inputExpression.eResource
				classResource.unload
				r.unload
				r.load(Collections.EMPTY_MAP)
				EcoreUtil.resolveAll(r)
				val rc = r.contents.head as RunConfiguration
				setInput(rc, rconfFile)
			}
		} else if (event.delta != null && (rconfFile != null && event.delta.concernsFile(rconfFile))) {
			val rs = rsProvider.get(rconfFile.getProject())
			val r = rs.getResource(URI.createURI(rconfFile.getFullPath().toString()), true)
			val classResource = inputExpression.eResource
			classResource.unload
			r.unload
			r.load(Collections.EMPTY_MAP)
			EcoreUtil.resolveAll(r)
			val rc = r.contents.head as RunConfiguration
			setInput(rc, rconfFile)
		}
		refreshJob.reschedule();
	}

	def protected boolean concernsFile(IResourceDelta delta, IFile file) {
		if (delta == null) {
			println("concernsFile delta==null")
			return false
		}
		if (file == null) {
			println("concernsFile file==null")
			return false
		}
		if (delta.fullPath == file.fullPath)
			return true
		return delta.affectedChildren.exists[concernsFile(file)]
	}

	override public void dispose() {
		super.dispose();
		workspace.removeResourceChangeListener(this);
	}

	override protected String computeDescription(IWorkbenchPartSelection workbenchPartSelection) {
		if (selectedFile == null) {
			return super.computeDescription(workbenchPartSelection);
		}
		val XtextEditor xtextEditor = workbenchPartSelection.getWorkbenchPart() as XtextEditor;
		if (xtextEditor.isDirty()) {
			return Messages.DerivedSourceView_EditorDirty;
		} else {
			return selectedFile.getFullPath().toString();
		}
	}

	override protected IDocument createDocument(String input) {
		val IDocument document = super.createDocument(input);
		return document;
	}

	override protected AnnotationModel createAnnotationModel() {
		val IFile file = getSelectedFile();
		return if(file != null) new ResourceMarkerAnnotationModel(file) else super.createAnnotationModel();
	}

	// TODO: this is just a slightly changed version of findRelevantNodes, there should be
	// an abstract implementation that fits both use cases
	def protected boolean findRelevantNodesForOutput(TraceTreeNode<RichStringOutputLocation> current, Set<TraceTreeNode<RichStringOutputLocation>> nodes, int offset,
		int length) {
		if (new Range(current.output.offset, current.output.offset + current.output.length).overlaps(
			new Range(offset, offset + length))) {
			val tempSet = new HashSet<TraceTreeNode<RichStringOutputLocation>>
			if (current.children.map[findRelevantNodesForOutput(tempSet, offset, length)].reduce[p1, p2|p1 && p2] ?:
				true) {
				nodes.add(current)
				return true
			} else {
				nodes.addAll(tempSet)
				return false
			}
		}
	}

	def protected boolean findRelevantNodes(TraceTreeNode<RichStringOutputLocation> current, Set<TraceTreeNode<RichStringOutputLocation>> nodes, int offset, int length) {
		val node = NodeModelUtils.findActualNodeFor(current.input.expression)
		if (current.input.expression instanceof XAbstractFeatureCall){
			val a = node.offset
			val b = node.length
		}
		
		if (new Range(node.offset, node.offset + node.length).overlaps(new Range(offset, offset + length))) {
			val tempSet = new HashSet<TraceTreeNode<RichStringOutputLocation>>
			if (current.children.map[findRelevantNodes(tempSet, offset, length)].reduce[p1, p2|p1 && p2] ?: true) {
				nodes.add(current)
				return true
			} else {
				if (!tempSet.empty){
					nodes.addAll(tempSet)
					return false
				}else{
					nodes.add(current)
					return true
				}
			}
		} else {

			// this could be a function call, in which case the children are actually somewhere else
			current.children.forEach[findRelevantNodes(nodes, offset, length)]
			return false
		}
	}

	override protected void selectAndReveal(IWorkbenchPartSelection workbenchPartSelection) {
		if (interpreter?.getTraces(RichStringTracingProvider.RICH_STRING_TRACING_PROVIDER_ID) != null) {
			val traces = interpreter?.getTraces(RichStringTracingProvider.RICH_STRING_TRACING_PROVIDER_ID) as TraceTreeNode<RichStringOutputLocation>
			if (workbenchPartSelection.selection instanceof TextSelection) {
				val ts = workbenchPartSelection.selection as TextSelection
				val nodes = new HashSet<TraceTreeNode<RichStringOutputLocation>>
				findRelevantNodes(traces, nodes, ts.offset, ts.length)
				if (!nodes.empty) {
					var start = Integer.MAX_VALUE
					var end = Integer.MIN_VALUE
					for (n : nodes) {
						start = Math.min(start, n.output.offset)
						end = Math.max(end, n.output.offset + n.output.length)
					}
					val length = end - start
					val textRegion = new TextRegion(start, length)

					//					openEditorAction.setSelectedRegion(textRegion);
					lastOffsetInView = start
					lastLengthInView = length

					getSourceViewer().revealRange(textRegion.getOffset(), textRegion.getLength());

					//getSourceViewer.setSelection(new TextSelection(textRegion.offset, textRegion.length), true)
					for (n : nodes) {
						try {
							sourceViewer.setTextColor(COLOR_SELECTED, n.output.offset, n.output.length, true)
						} catch (IllegalArgumentException e) {
							// do nothing
						}
					}
				}
			}
		}
	}

	protected static class RefreshJob extends UIJob {
		private DerivedSourceView view

		new(ISchedulingRule schedulingRule, DerivedSourceView view) {
			super(Messages.DerivedSourceView_RefreshJobTitle);
			this.view = view
			setRule(schedulingRule);
		}

		override public IStatus runInUIThread(IProgressMonitor monitor) {
			view.computeAndSetInput(
				new DefaultWorkbenchPartSelection(view.getSite().getPage().getActivePart(),
					view.getSite().getPage().getSelection()), true);
			return Status.OK_STATUS;
		}

		def protected void reschedule() {
			cancel();
			schedule();
		}
	}

}
