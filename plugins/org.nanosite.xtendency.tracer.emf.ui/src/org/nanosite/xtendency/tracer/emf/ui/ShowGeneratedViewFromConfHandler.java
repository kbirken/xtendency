package org.nanosite.xtendency.tracer.emf.ui;

import org.eclipse.core.commands.AbstractHandler;
import org.eclipse.core.commands.ExecutionEvent;
import org.eclipse.core.commands.ExecutionException;
import org.eclipse.core.commands.IHandler;
import org.eclipse.core.resources.IFile;
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
import org.nanosite.xtendency.tracer.runConf.RunConfiguration;

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
				RunConfiguration rc = (RunConfiguration) r.getContents().get(0);
				EcoreUtil.resolveAll(rc);

				try {
					try {
						GeneratedTreeView view = (GeneratedTreeView) HandlerUtil
								.getActiveWorkbenchWindow(event)
								.getActivePage()
								.showView(
										"org.nanosite.xtendency.tracer.emf.ui.generatedView");
						view.setInput(rc, (IFile) s);
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
