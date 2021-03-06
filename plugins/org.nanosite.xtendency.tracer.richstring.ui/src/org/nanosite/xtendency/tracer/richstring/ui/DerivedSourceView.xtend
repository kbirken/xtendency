package org.nanosite.xtendency.tracer.richstring.ui

import com.google.common.collect.HashMultiset
import com.google.common.collect.Multiset
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.eclipse.core.resources.IFile
import org.eclipse.core.runtime.jobs.ISchedulingRule
import org.eclipse.jface.text.Document
import org.eclipse.jface.text.IDocument
import org.eclipse.jface.text.TextSelection
import org.eclipse.jface.text.source.Annotation
import org.eclipse.jface.text.source.AnnotationRulerColumn
import org.eclipse.jface.text.source.CompositeRuler
import org.eclipse.jface.text.source.IOverviewRuler
import org.eclipse.jface.text.source.LineNumberRulerColumn
import org.eclipse.jface.text.source.OverviewRuler
import org.eclipse.jface.text.source.SourceViewer
import org.eclipse.jface.text.source.projection.ProjectionViewer
import org.eclipse.jface.viewers.ISelection
import org.eclipse.jface.viewers.ISelectionChangedListener
import org.eclipse.jface.viewers.SelectionChangedEvent
import org.eclipse.swt.SWT
import org.eclipse.swt.graphics.Color
import org.eclipse.swt.graphics.RGB
import org.eclipse.swt.widgets.Composite
import org.eclipse.swt.widgets.Display
import org.eclipse.ui.IPartListener2
import org.eclipse.ui.IWorkbenchPart
import org.eclipse.ui.IWorkbenchPartReference
import org.eclipse.ui.PlatformUI
import org.eclipse.ui.part.FileEditorInput
import org.eclipse.ui.texteditor.DefaultMarkerAnnotationAccess
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.ui.editor.SchedulingRuleFactory
import org.eclipse.xtext.ui.views.DefaultWorkbenchPartSelection
import org.eclipse.xtext.ui.views.IWorkbenchPartSelection
import org.eclipse.xtext.util.TextRegion
import org.eclipse.xtext.xbase.ui.editor.XbaseEditor
import org.nanosite.xtendency.tracer.core.SynchronizedInterpreterAccess
import org.nanosite.xtendency.tracer.core.TraceTreeNode
import org.nanosite.xtendency.tracer.core.ui.AbstractGeneratedView
import org.nanosite.xtendency.tracer.richstring.RichStringOutputLocation
import org.nanosite.xtendency.tracer.richstring.RichStringTracingProvider

import static org.eclipse.jface.resource.JFaceResources.*
import static org.eclipse.ui.editors.text.EditorsUI.*
import org.nanosite.xtendency.interpreter.XtendEvaluationResult

@Data class SelectionEvent {
	int offset
	int length
	long time
}

/**
 *
 * Heavily inspired by Xtend's DerivedSourceView by
 * @author Sven Efftinge - Initial contribution and API
 * @author Michael Clay
 */
public class DerivedSourceView extends AbstractGeneratedView implements IPartListener2 {
	protected static final int VERTICAL_RULER_WIDTH = 12;
	protected static final int OVERVIEW_RULER_WIDTH = 12;
	private static final ISchedulingRule SEQUENCE_RULE = SchedulingRuleFactory.INSTANCE.newSequence();

	private static final Color COLOR_SELECTED = new Color(Display.getCurrent, 255, 0, 0)
	private static final Color COLOR_DEFAULT = new Color(Display.getCurrent, 0, 0, 0)

	private Map<IWorkbenchPart, Multiset<SelectionEvent>> lastEditorSelection = new HashMap<IWorkbenchPart, Multiset<SelectionEvent>>

	private int lastOffsetInView = -1
	private int lastLengthInView = -1
	private Set<IWorkbenchPart> justActivated = new HashSet<IWorkbenchPart>

	private DefaultMarkerAnnotationAccess defaultMarkerAnnotationAccess = new DefaultMarkerAnnotationAccess();

	private ProjectionViewer sourceViewer


	new() {
		super()
		interpreter.addTracingProvider(new RichStringTracingProvider)
		colorRegistry.put("de.itemis.codegenutil.ui.DerivedSourceView.backgroundColor", new RGB(255, 255, 255))
	}

	override selectionChanged(IWorkbenchPart workbenchPart, ISelection selection) {
		if (workbenchPart instanceof XbaseEditor) {
			if (workbenchPart.editorInput instanceof FileEditorInput) {
				val fei = workbenchPart.editorInput as FileEditorInput
				if (classManager.usedClasses.keySet.contains(fei.file)) {
					if (justActivated.contains(workbenchPart)){
						justActivated.remove(workbenchPart)
						return
					}

					if (selection instanceof TextSelection) {
						val lastSelection = lastEditorSelection.get(workbenchPart)
						val currentTime = System.currentTimeMillis
						if (lastSelection != null){
							for (s : lastSelection){
								if (currentTime > s.time + 3000)
									lastSelection.remove(s)
								else if (selection.offset == s.offset && selection.length == s.length){
									lastSelection.remove(s)
									return
								}
							}
						}
						selectAndReveal(new DefaultWorkbenchPartSelection(workbenchPart, selection))
					}
				}
			}
		} else if (workbenchPart == this &&
			interpreter?.getTraces(RichStringTracingProvider.RICH_STRING_TRACING_PROVIDER_ID) != null) {
			if (selection instanceof TextSelection) {
				if (!(selection.offset == lastOffsetInView && selection.length == lastLengthInView)) {
					val nodesMap = new HashMap<IFile, Set<TraceTreeNode<RichStringOutputLocation>>>
					findRelevantNodesForOutput(
						interpreter.getTraces(RichStringTracingProvider.RICH_STRING_TRACING_PROVIDER_ID) as TraceTreeNode<RichStringOutputLocation>,
						nodesMap, selection.offset, selection.length)
					
					
					if (!nodesMap.empty) {
						val selected = nodesMap.selectFile
						val file = selected.key
						val nodes = selected.value
						var start = Integer.MAX_VALUE
						var end = Integer.MIN_VALUE
						for (n : nodes) {
							val node = NodeModelUtils.findActualNodeFor(n.input.expression)
							start = Math.min(start, node.offset)
							end = Math.max(end, node.offset + node.length)
						}
						val length = end - start
						val fileName = file.name

						val desc = PlatformUI.getWorkbench.editorRegistry.getDefaultEditor(fileName)
						val editor = PlatformUI.workbench.activeWorkbenchWindow.activePage.openEditor(new FileEditorInput(file), desc.id)
						lastEditorSelection.safeGet(editor).add(new SelectionEvent(start, length, System.currentTimeMillis))
						if (editor instanceof XbaseEditor)
							editor.selectAndReveal(start, length)
					}
				}
			}
		}
	}
	
	def Pair<IFile, Set<TraceTreeNode<RichStringOutputLocation>>> selectFile(Map<IFile, Set<TraceTreeNode<RichStringOutputLocation>>> files){
		val activeEditor = PlatformUI.workbench.activeWorkbenchWindow.activePage.activeEditor
		if (activeEditor != null && activeEditor.editorInput instanceof FileEditorInput){
			val openFile = (activeEditor.editorInput as FileEditorInput).file
			if (files.keySet.contains(openFile)){
				return openFile -> files.get(openFile)
			}
		}
		// select the one with the most tracepoints i guess?
		val selectedFile = files.keySet.maximize[files.get(it).size]
		return selectedFile -> files.get(selectedFile)
	}
	
	def <T> T maximize(Iterable<T> lst, (T)=>Integer func){
		var best = Integer.MIN_VALUE
		var T result = null
		for (t : lst){
			val score = func.apply(t)
			if (score > best){
				best = score
				result = t
			}	
		}
		result
	}

	def isIgnored(IWorkbenchPartSelection s) {
		return !(s.selection instanceof TextSelection)
	}

	def protected SourceViewer createSourceViewer(Composite parent) {
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

	def protected boolean isValidSelection(IWorkbenchPartSelection workbenchPartSelection) {
		return this.executionContext != null
	}

	def protected String getBackgroundColorKey() {
		return "de.itemis.codegenutil.ui.DerivedSourceView.backgroundColor"; //$NON-NLS-1$
	}

	def protected String getViewerFontName() {
		return "org.eclipse.xtend.ui.editors.textfont"; //$NON-NLS-1$
	}



	def protected String computeInput(IWorkbenchPartSelection workbenchPartSelection) {
		val interpResult = SynchronizedInterpreterAccess.evaluate(interpreter, executionContext.function, initialInstance, classManager, arguments)
		if (interpResult.result != null && interpResult.result instanceof CharSequence) {
			return interpResult.result.toString
		} else {
			if (interpResult instanceof XtendEvaluationResult)
				return interpResult.stackTrace
			else
				return interpResult.exception.stackTraceString
		}
	}


	override public void partVisible(IWorkbenchPartReference ref) {
		justActivated += ref.getPart(false)
	}

	override public void dispose() {
		super.dispose();
		workspace.removeResourceChangeListener(this);
	}

	// TODO: this is just a slightly changed version of findRelevantNodes, there should be
	// an abstract implementation that fits both use cases
	def protected boolean findRelevantNodesForOutput(TraceTreeNode<RichStringOutputLocation> current,
		Map<IFile, Set<TraceTreeNode<RichStringOutputLocation>>> nodes, int offset, int length) {
		if (new Range(current.output.offset, current.output.offset + current.output.length).overlaps(
			new Range(offset, offset + length))) {
			
			val tempSet = new HashMap<IFile, Set<TraceTreeNode<RichStringOutputLocation>>>
			if (current.children.map[findRelevantNodesForOutput(tempSet, offset, length)].reduce[p1, p2|p1 && p2] ?:
				true) {
				val f = classManager.usedClasses.inverse.get(current.input.expression.eResource.URI)

				nodes.safeGet(f).add(current)
				return true
			} else {
				for (f : tempSet.keySet){
					nodes.safeGet(f).addAll(tempSet.get(f))
				}
				return false
			}
		}
		//TODO: else branch??? is this correct?
		false
	}
	
	def Set<TraceTreeNode<RichStringOutputLocation>> safeGet(Map<IFile, Set<TraceTreeNode<RichStringOutputLocation>>> map, IFile f){
		if (map.containsKey(f)){
			return map.get(f)
		}else{
			val result = new HashSet<TraceTreeNode<RichStringOutputLocation>>
			map.put(f, result)
			result
		}
	}
	
	def <K> Multiset<SelectionEvent> safeGet(Map<K, Multiset<SelectionEvent>> m, K k){
		if (m.containsKey(k)){
			m.get(k)
		}else{
			val result = HashMultiset.create
			m.put(k, result)
			result
		}
	}

	def protected boolean findRelevantNodes(TraceTreeNode<RichStringOutputLocation> current,
		Set<TraceTreeNode<RichStringOutputLocation>> nodes, int offset, int length) {
		val node = NodeModelUtils.findActualNodeFor(current.input.expression)

		if (new Range(node.offset, node.offset + node.length).overlaps(new Range(offset, offset + length))) {
			val tempSet = new HashSet<TraceTreeNode<RichStringOutputLocation>>
			if (current.children.map[findRelevantNodes(tempSet, offset, length)].reduce[p1, p2|p1 && p2] ?: true) {
				nodes.add(current)
				return true
			} else {
				if (!tempSet.empty) {
					nodes.addAll(tempSet)
					return false
				} else {
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

	def protected void selectAndReveal(IWorkbenchPartSelection workbenchPartSelection) {
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

					sourceViewer.revealRange(textRegion.getOffset(), textRegion.getLength());

					//getSourceViewer.setSelection(new TextSelection(textRegion.offset, textRegion.length), true)
					println("number of nodes is " + nodes.length)
					sourceViewer.setTextColor(COLOR_DEFAULT, 0, (sourceViewer.input as IDocument).length, true)
				
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
	
	override protected computeAndSetInput(IWorkbenchPartSelection selection) {
		sourceViewer.input = new Document(computeInput(selection))
	}
	
	override doCreatePartControl(Composite parent) {
		createSourceViewer(parent)
	}
	
	override setFocus() {
	}
	
	override acceptsClass(Class<?> returnType) {
		CharSequence.isAssignableFrom(returnType)
	}
	
}
