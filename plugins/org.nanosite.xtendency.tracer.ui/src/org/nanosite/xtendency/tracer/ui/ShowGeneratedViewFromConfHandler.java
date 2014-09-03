package org.nanosite.xtendency.tracer.ui;

import org.eclipse.core.commands.AbstractHandler;
import org.eclipse.core.commands.ExecutionEvent;
import org.eclipse.core.commands.ExecutionException;
import org.eclipse.core.commands.IHandler;
import org.eclipse.core.commands.IHandlerListener;
import org.eclipse.core.resources.IFile;
import org.eclipse.core.runtime.Path;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.resource.Resource;
import org.eclipse.emf.ecore.resource.ResourceSet;
import org.eclipse.emf.ecore.util.EcoreUtil;
import org.eclipse.jface.viewers.ISelection;
import org.eclipse.jface.viewers.TreeSelection;
import org.eclipse.ui.PartInitException;
import org.eclipse.ui.PlatformUI;
import org.eclipse.ui.handlers.HandlerUtil;
import org.eclipse.xtend.core.xtend.XtendFile;
import org.eclipse.xtend.core.xtend.XtendFunction;
import org.eclipse.xtend.core.xtend.XtendTypeDeclaration;
import org.eclipse.xtend.ide.internal.XtendActivator;
import org.eclipse.xtext.naming.QualifiedName;
import org.eclipse.xtext.ui.resource.IResourceSetProvider;
import org.eclipse.xtext.xbase.XBlockExpression;
import org.eclipse.xtext.xbase.XExpression;
import org.eclipse.xtext.xbase.XbaseFactory;
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext;
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationContext;
import org.nanosite.xtendency.tracer.runConf.RunConfiguration;

import com.google.inject.Inject;

public class ShowGeneratedViewFromConfHandler extends AbstractHandler {

	
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
				RunConfiguration rc = (RunConfiguration) r.getContents().get(0);
				EcoreUtil.resolveAll(rc);
				XtendFile f = (XtendFile) rc.getClazz().eContainer(); 
				String filePath = dropFirstSegment(f.eResource().getURI());
				IFile file = ((IFile)s).getProject().getFile(Path.fromPortableString(filePath));
				XtendTypeDeclaration typeDecl = rc.getClazz();
				XtendFunction func = rc.getFunction();
				XExpression inputExpression = func.getExpression();
				IEvaluationContext context = new DefaultEvaluationContext();
				//context.newValue(QualifiedName.create("param"), "someString");
				
				XBlockExpression combinedExpression = XbaseFactory.eINSTANCE.createXBlockExpression();
				rc.eResource().getContents().add(combinedExpression);
				if (rc.getInit() != null && rc.getInit().getBlock() != null){
					combinedExpression.getExpressions().addAll(rc.getInit().getBlock().getExpressions());
				}
				combinedExpression.getExpressions().add(inputExpression);
				try {
					try {
						DerivedSourceView view = (DerivedSourceView) HandlerUtil
								.getActiveWorkbenchWindow(event)
								.getActivePage()
								.showView(
										"org.nanosite.xtendency.tracer.ui.generatedView");
						view.setInput(typeDecl, combinedExpression, context, file);
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
	
	private String dropFirstSegment(URI uri){
		StringBuilder sb = new StringBuilder();
		for (int i = 2; i < uri.segmentCount(); i++){
			sb.append("/");
			sb.append(uri.segment(i));
		}
		return sb.toString();
	}

}