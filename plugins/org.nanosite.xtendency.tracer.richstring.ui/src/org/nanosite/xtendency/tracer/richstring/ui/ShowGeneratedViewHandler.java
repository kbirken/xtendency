package org.nanosite.xtendency.tracer.richstring.ui;

import org.eclipse.core.commands.AbstractHandler;
import org.eclipse.core.commands.ExecutionEvent;
import org.eclipse.core.commands.ExecutionException;
import org.eclipse.core.commands.IHandler;
import org.eclipse.core.commands.IHandlerListener;
import org.eclipse.core.resources.IFile;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl;
import org.eclipse.jface.viewers.ISelection;
import org.eclipse.jface.viewers.TreeSelection;
import org.eclipse.ui.IEditorReference;
import org.eclipse.ui.IWorkbenchPage;
import org.eclipse.ui.PartInitException;
import org.eclipse.ui.PlatformUI;
import org.eclipse.ui.handlers.HandlerUtil;
import org.eclipse.xtend.core.xtend.XtendFile;
import org.eclipse.xtend.core.xtend.XtendFunction;
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration;
import org.eclipse.xtend.ide.internal.XtendActivator;
import org.eclipse.xtext.naming.QualifiedName;
import org.eclipse.xtext.ui.resource.IResourceSetProvider;
import org.eclipse.xtext.xbase.XExpression;
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext;
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationContext;
import org.nanosite.xtendency.tracer.richstring.ui.DerivedSourceView;

import com.google.inject.Inject;

public class ShowGeneratedViewHandler extends AbstractHandler {
	
	@Inject 
	private IResourceSetProvider rsProvider; 

	@SuppressWarnings("restriction")
	@Override
	public Object execute(ExecutionEvent event) throws ExecutionException {
		System.out.println("Executing command");
		ISelection selection = HandlerUtil.getCurrentSelection(event);
		if (selection instanceof TreeSelection) {
			TreeSelection ts = (TreeSelection) selection;
			Object s = ts.getFirstElement();
			if (s instanceof IFile) {
				XtendActivator.getInstance().getInjector(XtendActivator.ORG_ECLIPSE_XTEND_CORE_XTEND).injectMembers(this);
				ResourceSet rs = rsProvider.get(((IFile) s).getProject());
				Resource r = rs.getResource(
						URI.createURI(((IFile) s).getFullPath().toString()),
						true);
				XtendFile f = (XtendFile) r.getContents().get(0);
				XtendTypeDeclaration typeDecl = f.getXtendTypes().get(0);
				XtendFunction func = (XtendFunction) typeDecl
						.getMembers().get(0);
				XExpression inputExpression = func.getExpression();
				IEvaluationContext context = new DefaultEvaluationContext();
				context.newValue(QualifiedName.create("param"), "someString");
				try {
					try {
						DerivedSourceView view = (DerivedSourceView) HandlerUtil
								.getActiveWorkbenchWindow(event)
								.getActivePage()
								.showView(
										"org.nanosite.xtendency.tracer.ui.generatedView");
						view.setInput(typeDecl, inputExpression, context, (IFile)s);
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
