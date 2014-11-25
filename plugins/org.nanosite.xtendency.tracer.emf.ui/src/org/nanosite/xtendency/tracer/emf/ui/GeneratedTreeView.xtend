package org.nanosite.xtendency.tracer.emf.ui

import java.util.ArrayList
import java.util.Collections
import java.util.List
import java.util.Map
import java.util.concurrent.Executors
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.util.EcoreUtil.EqualityHelper
import org.eclipse.emf.edit.provider.ComposedAdapterFactory
import org.eclipse.emf.edit.provider.ReflectiveItemProviderAdapterFactory
import org.eclipse.emf.edit.provider.resource.ResourceItemProviderAdapterFactory
import org.eclipse.jface.text.Document
import org.eclipse.jface.text.source.Annotation
import org.eclipse.jface.text.source.AnnotationRulerColumn
import org.eclipse.jface.text.source.CompositeRuler
import org.eclipse.jface.text.source.IOverviewRuler
import org.eclipse.jface.text.source.LineNumberRulerColumn
import org.eclipse.jface.text.source.OverviewRuler
import org.eclipse.jface.text.source.projection.ProjectionViewer
import org.eclipse.jface.viewers.ArrayContentProvider
import org.eclipse.jface.viewers.ColumnLabelProvider
import org.eclipse.jface.viewers.DoubleClickEvent
import org.eclipse.jface.viewers.IDoubleClickListener
import org.eclipse.jface.viewers.ISelection
import org.eclipse.jface.viewers.TableViewer
import org.eclipse.jface.viewers.TableViewerColumn
import org.eclipse.jface.viewers.TreeNode
import org.eclipse.jface.viewers.TreeNodeContentProvider
import org.eclipse.jface.viewers.TreeSelection
import org.eclipse.jface.viewers.TreeViewer
import org.eclipse.swt.SWT
import org.eclipse.swt.custom.StackLayout
import org.eclipse.swt.layout.FillLayout
import org.eclipse.swt.layout.GridData
import org.eclipse.swt.widgets.Composite
import org.eclipse.swt.widgets.Display
import org.eclipse.ui.IWorkbenchPart
import org.eclipse.ui.PlatformUI
import org.eclipse.ui.part.FileEditorInput
import org.eclipse.ui.texteditor.DefaultMarkerAnnotationAccess
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.ui.views.IWorkbenchPartSelection
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.ui.editor.XbaseEditor
import org.nanosite.xtendency.tracer.core.SynchronizedInterpreterAccess
import org.nanosite.xtendency.tracer.core.ui.AbstractGeneratedView
import org.nanosite.xtendency.tracer.emf.EmfTracingProvider

import static org.eclipse.ui.editors.text.EditorsUI.*
import static org.eclipse.xtext.ui.util.DisplayRunHelper.*

import static extension org.nanosite.xtendency.tracer.emf.ui.GeneratedTreeView.*
import org.nanosite.xtendency.tracer.core.XtendEvaluationResult

class GeneratedTreeView extends AbstractGeneratedView {

	protected TreeViewer tree
	protected TableViewer table
	protected ProjectionViewer errorViewer
	protected Composite errorCompositeContainer
	protected Composite errorComposite
	protected Composite mainComposite
	private int computeCount = 0
	
	private DefaultMarkerAnnotationAccess defaultMarkerAnnotationAccess = new DefaultMarkerAnnotationAccess();
	protected static final int VERTICAL_RULER_WIDTH = 12;
	protected static final int OVERVIEW_RULER_WIDTH = 12;

	new() {
		super()
		interpreter.addTracingProvider(new EmfTracingProvider)
	}

	override doCreatePartControl(Composite parent) {
		errorCompositeContainer = new Composite(parent, SWT.NONE)
		val stackLayout = new StackLayout
		val errorGridContainerData = new GridData(SWT.FILL, SWT.FILL, true, true);
		val errorGridData = new GridData(SWT.FILL, SWT.FILL, true, true);
		val gridData = new GridData(SWT.FILL, SWT.FILL, true, true);
		errorCompositeContainer.layoutData = errorGridContainerData
		errorCompositeContainer.layout = stackLayout
		
		val IOverviewRuler overviewRuler = new OverviewRuler(defaultMarkerAnnotationAccess, OVERVIEW_RULER_WIDTH,
			getSharedTextColors());
		val AnnotationRulerColumn annotationRulerColumn = new AnnotationRulerColumn(VERTICAL_RULER_WIDTH,
			defaultMarkerAnnotationAccess);

		annotationRulerColumn.addAnnotationType(Annotation.TYPE_UNKNOWN);
		val LineNumberRulerColumn lineNumberRuleColumn = new LineNumberRulerColumn();
		lineNumberRuleColumn.setBackground(Display.getDefault().getSystemColor(SWT.COLOR_WIDGET_BACKGROUND));
		//lineNumberRuleColumn.setFont(getFont(getViewerFontName()));
		val CompositeRuler compositeRuler = new CompositeRuler();
		compositeRuler.addDecorator(0, annotationRulerColumn);
		compositeRuler.addDecorator(1, lineNumberRuleColumn);
		
		errorComposite = new Composite(errorCompositeContainer, SWT.BORDER);
		errorComposite.setLayoutData(errorGridData);
		errorComposite.setLayout(new FillLayout);
		
		errorViewer = new ProjectionViewer(errorComposite, compositeRuler, overviewRuler, true,
			SWT.V_SCROLL.bitwiseOr(SWT.H_SCROLL));
		errorViewer.editable = false
		
		mainComposite = new Composite(errorCompositeContainer, SWT.BORDER);
		stackLayout.topControl = mainComposite
		mainComposite.setLayoutData(gridData);
		mainComposite.setLayout(new FillLayout);
		
		tree = new TreeViewer(mainComposite, SWT.BORDER.bitwiseOr(SWT.H_SCROLL).bitwiseOr(SWT.V_SCROLL))
		tree.contentProvider = new TreeNodeContentProvider

		val adapterFactory = new ComposedAdapterFactory(ComposedAdapterFactory.Descriptor.Registry.INSTANCE);

		adapterFactory.addAdapterFactory(new ReflectiveItemProviderAdapterFactory());
		adapterFactory.addAdapterFactory(new ResourceItemProviderAdapterFactory());
		val emfLabelProvider = new EmfLabelProvider(adapterFactory)
		tree.setLabelProvider(emfLabelProvider);
		tree.addDoubleClickListener(
			new IDoubleClickListener() {

				override doubleClick(DoubleClickEvent event) {
					val selected = (event.selection as TreeSelection).firstElement as TreeNode
					val traces = interpreter.getTraces(EmfTracingProvider.EMF_TRACING_PROVIDER_ID).output as Map<Pair<EObject, EStructuralFeature>, List<Pair<Pair<XExpression, Map<String, Object>>, Object>>>
					val nodeValue = selected.value as Pair<Pair<EObject, EStructuralFeature>, Object>
					val setters = traces.get(nodeValue.key)
					if (setters != null && !setters.empty) {
						
						val relevantAssignment = setters.findLast[concerns(nodeValue)]
						if (relevantAssignment != null) {
							val node = NodeModelUtils.findActualNodeFor(relevantAssignment.key.key)
							val selectedURI = relevantAssignment.key.key.eResource.URI
							val selectedFile = getFileForUri(selectedURI, tecFile.project)
							val desc = PlatformUI.getWorkbench().getEditorRegistry().getDefaultEditor(selectedFile.getName());
							val editor = PlatformUI.workbench.activeWorkbenchWindow.activePage.openEditor(
								new FileEditorInput(selectedFile), desc.id)
							if (editor instanceof XbaseEditor) {
								editor.selectAndReveal(node.offset, node.length)
								val tableInput = toPairList(relevantAssignment.key.value)
								Collections.sort(tableInput, [p1, p2 | p1.key.compareTo(p2.key)])
								table.setInput(tableInput)
								table.table.columns.forEach[pack]
							}
						}
					}
				}	
			})

		table = new TableViewer(mainComposite, SWT.BORDER.bitwiseOr(SWT.H_SCROLL).bitwiseOr(SWT.V_SCROLL))
		table.contentProvider = ArrayContentProvider.getInstance()

		val colName = new TableViewerColumn(table, SWT.NONE);

		colName.getColumn().setText("Variable");
		colName.setLabelProvider(
			new ColumnLabelProvider() {
				override String getText(Object element) {
					(element as Pair<String, Object>).key
				}
			});

		val colValue = new TableViewerColumn(table, SWT.NONE);
		colValue.getColumn().setText("Value");
		colValue.setLabelProvider(
			new ColumnLabelProvider() {
				override String getText(Object element) {
					(element as Pair<String, Object>)?.value?.toString ?: "null"
				}

				override getImage(Object element) {
					emfLabelProvider.getImage((element as Pair<String, Object>).value)
				}

			});
		table.table.columns.forEach[pack]
	}
	
	def static boolean concerns(Pair<Pair<XExpression, Map<String, Object>>, Object> assg, Pair<Pair<EObject, EStructuralFeature>, Object> nodeValue) {
		if (assg.value == nodeValue.value)
			return true
		if (assg.value instanceof Iterable<?>){
			for (o : assg.value as Iterable<?>){
				if (o == nodeValue.value){
					return true
				}
			}
		}
		false
	}

	def <K, V> List<Pair<K, V>> toPairList(Map<K, V> map) {
		val result = new ArrayList<Pair<K, V>>
		for (k : map.keySet) {
			result += k -> map.get(k)
		}
		result
	}

	override setFocus() {
		// TODO ? 
	}

	def protected void setTreeInput(EObject eo) {
		if (eo == null){
			tree.input = null
		}else{
			val eqHelper = new TreeEqualityHelper
			val root = eo.convertToTreeNode(null, null, eqHelper)
			val TreeNode[] nodeArray = newArrayOfSize(1)
			nodeArray.set(0, root)
			val expanded = tree.expandedElements
			tree.input = nodeArray
			tree.expandedElements = expanded
		}
	}

	def dispatch TreeNode convertToTreeNode(EObject o, EObject parent, EStructuralFeature f, EqualityHelper helper) {
		val result = new EMFTreeNode((parent -> f) -> o, helper)
		result.children = [ |
			val children = new ArrayList<TreeNode>
			for (sf : o.eClass.EAllStructuralFeatures) {
				if (o.eIsSet(sf)) {
					val value = o.eGet(sf)
					children += value.convertToTreeNode(o, sf, helper)
				}
			}
			children
		]
		result
	}

	def dispatch TreeNode convertToTreeNode(Object o, EObject parent, EStructuralFeature f, EqualityHelper helper) {
		new EMFTreeNode((parent -> f) -> o, helper)
	}

	def dispatch TreeNode convertToTreeNode(List<?> o, EObject parent, EStructuralFeature f, EqualityHelper helper) {
		val result = new EMFTreeNode((parent -> f) -> o, helper)
		result.children = [ |
			val children = new ArrayList<TreeNode>
			for (e : o) {
				if (e != null) {
					children += e.convertToTreeNode(parent, f, helper)
				}
			}
			children
		]
		result
	}

	override selectionChanged(IWorkbenchPart part, ISelection selection) {
	}

	def protected Display getDisplay() {
		val shell = getSite().getShell();
		if (shell == null || shell.isDisposed()) {
			return null;
		}
		val display = shell.getDisplay();
		if (display == null || display.isDisposed()) {
			return null;
		}
		return display;
	}

	override protected computeAndSetInput(IWorkbenchPartSelection selection) {
		val currentCount = computeCount + 1;
		computeCount++;
		val threadFactory = Executors.defaultThreadFactory();
		val thread = threadFactory.newThread(
			new Runnable() {
				override void run() {
					if (currentCount != computeCount) {
						return;
					}
					val input = computeInput(selection);
//					if (input == null) {
//						return;
//					}
					val display = getDisplay();
					if (display == null) {
						return;
					}
					runAsyncInDisplayThread(
						new Runnable() {
							override void run() {
								if (computeCount != currentCount || getViewSite().getShell().isDisposed()) {
									return;
								}
								if (input.result != null && input.result instanceof EObject) {
									setTreeInput(input.result as EObject)
									(errorCompositeContainer.getLayout as StackLayout).topControl = mainComposite
									errorCompositeContainer.layout()
								} else {
									setTreeInput(null)
									val stackTrace = if (input instanceof XtendEvaluationResult) input.stackTrace else input.exception.stackTraceString
									errorViewer.input = new Document(stackTrace)
									(errorCompositeContainer.getLayout as StackLayout).topControl = errorComposite
									errorCompositeContainer.layout()
								}
							}

						});
				}
			});
		thread.setDaemon(true);
		thread.setPriority(Thread.MIN_PRIORITY);
		thread.start();
	}

	def protected computeInput(IWorkbenchPartSelection workbenchPartSelection) {
		println("recomputing input")
		val interpResult = SynchronizedInterpreterAccess.evaluate(interpreter, executionContext.function, initialInstance, classManager, arguments)
		interpResult
	}

	override acceptsClass(Class<?> returnType) {
		EObject.isAssignableFrom(returnType)
	}
	
}
