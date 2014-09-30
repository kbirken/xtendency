package org.nanosite.xtendency.tracer.emf.ui

import org.eclipse.ui.part.ViewPart
import org.eclipse.swt.widgets.Composite
import org.eclipse.jface.viewers.TreeViewer
import org.eclipse.jface.viewers.TreeNodeContentProvider
import org.eclipse.emf.edit.provider.ReflectiveItemProviderAdapterFactory
import org.eclipse.emf.edit.provider.ComposedAdapterFactory
import org.eclipse.emf.edit.provider.resource.ResourceItemProviderAdapterFactory
import org.eclipse.emf.edit.ui.provider.AdapterFactoryLabelProvider
import org.eclipse.ui.part.FileEditorInput
import org.eclipse.emf.ecore.EObject
import org.eclipse.jface.viewers.TreeNode
import java.util.ArrayList
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.xtend.core.xtend.XtendFile
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationContext
import com.google.inject.Injector
import com.google.inject.Inject
import org.nanosite.xtendency.tracer.core.TracingInterpreter
import org.eclipse.core.runtime.Path
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.emf.common.util.URI
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.jdt.core.JavaCore
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration
import org.eclipse.core.resources.IResourceChangeListener
import org.eclipse.jface.viewers.ISelectionChangedListener
import org.eclipse.xtend.ide.internal.XtendActivator
import org.eclipse.core.resources.IWorkspace
import org.eclipse.ui.ISelectionListener
import org.eclipse.core.resources.IResourceChangeEvent
import org.eclipse.ui.IWorkbenchPart
import org.eclipse.jface.viewers.ISelection
import java.util.Collections
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.xtext.ui.resource.IResourceSetProvider
import org.eclipse.xtend.core.xtend.XtendFunction
import org.eclipse.ui.progress.UIJob
import org.eclipse.core.runtime.jobs.ISchedulingRule
import org.eclipse.core.runtime.IStatus
import org.eclipse.core.runtime.IProgressMonitor
import org.eclipse.core.runtime.Status
import org.eclipse.xtext.ui.views.DefaultWorkbenchPartSelection
import org.eclipse.xtext.ui.views.IWorkbenchPartSelection
import java.util.concurrent.Executors

import static org.eclipse.xtext.ui.util.DisplayRunHelper.*
import org.eclipse.swt.widgets.Display
import org.eclipse.core.resources.IResourceDelta
import org.eclipse.xtext.ui.editor.SchedulingRuleFactory
import org.nanosite.xtendency.tracer.core.SynchronizedInterpreterAccess
import org.nanosite.xtendency.tracer.emf.EmfTracingProvider
import org.eclipse.swt.SWT
import java.util.Arrays
import java.util.List
import org.eclipse.jface.viewers.IDoubleClickListener
import org.eclipse.jface.viewers.DoubleClickEvent
import org.eclipse.jface.viewers.TreeSelection
import java.util.Map
import org.eclipse.emf.common.util.EList
import org.eclipse.ui.PlatformUI
import org.eclipse.xtext.xbase.ui.editor.XbaseEditor
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.swt.layout.GridData
import org.eclipse.swt.layout.GridLayout
import org.eclipse.jface.viewers.TableViewer
import org.eclipse.jface.viewers.ArrayContentProvider
import org.eclipse.jface.viewers.TableViewerColumn
import org.eclipse.jface.viewers.ColumnLabelProvider
import org.eclipse.swt.layout.FillLayout
import org.nanosite.xtendency.tracer.tracingExecutionContext.ExecutionContext
import org.nanosite.xtendency.tracer.core.ui.AbstractGeneratedView
import org.eclipse.ui.IWorkbenchPartReference

class GeneratedTreeView extends AbstractGeneratedView {

	protected TreeViewer tree
	protected TableViewer table
	private int computeCount = 0

	new() {
		super()
		workspace.addResourceChangeListener(this)
		interpreter.addTracingProvider(new EmfTracingProvider)
	}

	override createPartControl(Composite parent) {
		val composite = new Composite(parent, SWT.BORDER);
		val gridData = new GridData(SWT.FILL, SWT.FILL, true, true);
		composite.setLayoutData(gridData);
		composite.setLayout(new FillLayout);
		tree = new TreeViewer(composite, SWT.BORDER.bitwiseOr(SWT.H_SCROLL).bitwiseOr(SWT.V_SCROLL))
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

		table = new TableViewer(composite, SWT.BORDER.bitwiseOr(SWT.H_SCROLL).bitwiseOr(SWT.V_SCROLL))
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

	def protected void setInput(EObject eo) {
		val root = eo.convertToTreeNode(null, null)
		val TreeNode[] nodeArray = newArrayOfSize(1)
		nodeArray.set(0, root)
		tree.input = nodeArray
	}

	def dispatch TreeNode convertToTreeNode(EObject o, EObject parent, EStructuralFeature f) {
		val result = new LazyTreeNode((parent -> f) -> o)
		result.children = [ |
			val children = new ArrayList<TreeNode>
			for (sf : o.eClass.EAllStructuralFeatures) {
				if (o.eIsSet(sf)) {
					val value = o.eGet(sf)
					children += value.convertToTreeNode(o, sf)
				}
			}
			children
		]
		result
	}

	def dispatch TreeNode convertToTreeNode(Object o, EObject parent, EStructuralFeature f) {
		new LazyTreeNode((parent -> f) -> o)
	}

	def dispatch TreeNode convertToTreeNode(List<?> o, EObject parent, EStructuralFeature f) {
		val result = new LazyTreeNode((parent -> f) -> o)
		result.children = [ |
			val children = new ArrayList<TreeNode>
			for (e : o) {
				if (e != null) {
					children += e.convertToTreeNode(parent, f)
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
					if (input == null) {
						return;
					}
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
								setInput(input);

							//selectAndReveal(workbenchPartSelection);
							}

						});
				}
			});
		thread.setDaemon(true);
		thread.setPriority(Thread.MIN_PRIORITY);
		thread.start();
	}

	def protected EObject computeInput(IWorkbenchPartSelection workbenchPartSelection) {
		println("recomputing input")
		val interpResult = SynchronizedInterpreterAccess.evaluate(interpreter, inputExpression, initialContext.fork)
		if (interpResult.result != null && interpResult.result instanceof EObject) {
			return interpResult.result as EObject
		} else {
			interpResult.exception.printStackTrace
			return null
		}
	}

}
