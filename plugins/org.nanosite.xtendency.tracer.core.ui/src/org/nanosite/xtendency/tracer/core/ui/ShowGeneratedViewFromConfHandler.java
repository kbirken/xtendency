package org.nanosite.xtendency.tracer.core.ui;

import org.eclipse.core.commands.AbstractHandler;
import org.eclipse.core.commands.ExecutionEvent;
import org.eclipse.core.commands.ExecutionException;
import org.eclipse.core.commands.IHandler;
import org.eclipse.core.resources.IFile;
import org.eclipse.core.runtime.IConfigurationElement;
import org.eclipse.core.runtime.Platform;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.util.EcoreUtil;
import org.eclipse.jface.viewers.ISelection;
import org.eclipse.jface.viewers.TreeSelection;
import org.eclipse.ui.PartInitException;
import org.eclipse.ui.PlatformUI;
import org.eclipse.ui.handlers.HandlerUtil;
import org.eclipse.xtend.ide.internal.XtendActivator;
import org.eclipse.xtext.ui.resource.IResourceSetProvider;
import org.eclipse.xtext.xbase.interpreter.impl.XbaseInterpreter;
import org.nanosite.xtendency.tracer.tracingExecutionContext.ExecutionContext;

import com.google.inject.Inject;

public class ShowGeneratedViewFromConfHandler extends AbstractHandler implements
		IHandler {
	
	@Inject
	private XbaseInterpreter interpreter;

	@Inject
	private IResourceSetProvider rsProvider;

	@Override
	public Object execute(ExecutionEvent event) throws ExecutionException {
		System.out.println("Executing command");
		ISelection selection = HandlerUtil.getCurrentSelection(event);
		if (selection instanceof TreeSelection) {
			TreeSelection ts = (TreeSelection) selection;
			Object s = ts.getFirstElement();
			if (s instanceof IFile) {
				XtendActivator
						.getInstance()
						.getInjector(
								XtendActivator.ORG_ECLIPSE_XTEND_CORE_XTEND)
						.injectMembers(this);
				ResourceSet rs = rsProvider.get(((IFile) s).getProject());
				Resource r = rs.getResource(
						URI.createURI(((IFile) s).getFullPath().toString()),
						true);
				ExecutionContext ec = (ExecutionContext) r.getContents().get(0);
				EcoreUtil.resolveAll(ec);
				IConfigurationElement[] views = Platform.getExtensionRegistry().getConfigurationElementsFor("org.nanosite.xtendency.tracer.view");
				
				String viewId = null;
				
				for (IConfigurationElement conf : views){
					if (conf.getAttribute("name").equals(ec.getView())){
						viewId = conf.getAttribute("extension");
					}
				}
				try {
					try {
						AbstractGeneratedView view = (AbstractGeneratedView) HandlerUtil
								.getActiveWorkbenchWindow(event)
								.getActivePage()
								.showView(
										viewId);
						view.setInput(ec, (IFile) s);
						PlatformUI.getWorkbench().getActiveWorkbenchWindow()
								.getSelectionService()
								.addSelectionListener(view);
					} finally {
					}

				} catch (PartInitException e) {
					// TODO Auto-generated catch block
					e.printStackTrace();
				}
			}
		}
		return null;
	}

}
