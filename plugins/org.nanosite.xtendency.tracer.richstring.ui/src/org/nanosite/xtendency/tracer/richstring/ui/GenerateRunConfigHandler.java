package org.nanosite.xtendency.tracer.richstring.ui;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.nio.file.Path;

import org.eclipse.core.commands.AbstractHandler;
import org.eclipse.core.commands.ExecutionEvent;
import org.eclipse.core.commands.ExecutionException;
import org.eclipse.core.commands.IHandler;
import org.eclipse.core.resources.IContainer;
import org.eclipse.core.resources.IFile;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.jdt.core.IJavaElement;
import org.eclipse.jface.dialogs.ErrorDialog;
import org.eclipse.jface.dialogs.IInputValidator;
import org.eclipse.jface.dialogs.InputDialog;
import org.eclipse.jface.text.ITextSelection;
import org.eclipse.ui.IEditorDescriptor;
import org.eclipse.ui.IWorkbenchPage;
import org.eclipse.ui.PlatformUI;
import org.eclipse.ui.handlers.HandlerUtil;
import org.eclipse.ui.part.FileEditorInput;
import org.eclipse.xtend.core.xtend.XtendFunction;
import org.eclipse.xtext.common.types.JvmIdentifiableElement;
import org.eclipse.xtext.resource.EObjectAtOffsetHelper;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.ui.editor.XtextEditor;
import org.eclipse.xtext.ui.editor.utils.EditorUtils;
import org.eclipse.xtext.util.concurrent.IUnitOfWork;
import org.eclipse.xtext.xbase.ui.editor.AbstractJvmElementHandler;
import org.nanosite.xtendency.tracer.richstring.ui.RunConfTemplateGenerator;
import org.nanosite.xtendency.tracer.ui.internal.RunConfActivator;

import com.google.inject.Inject;


public class GenerateRunConfigHandler extends AbstractHandler  {
	
	@Inject
	private EObjectAtOffsetHelper eObjectAtOffsetHelper;
	
	public GenerateRunConfigHandler(){
		System.out.println("making a handler");
		RunConfActivator.getInstance().getInjector(RunConfActivator.ORG_NANOSITE_XTENDENCY_TRACER_RUNCONF).injectMembers(this);
	}

	public Object execute(final ExecutionEvent event) throws ExecutionException {
		final XtextEditor editor = EditorUtils.getActiveXtextEditor(event);
		if (editor != null) {
			final ITextSelection selection = (ITextSelection) editor.getSelectionProvider().getSelection();
			editor.getDocument().readOnly(new IUnitOfWork<Void, XtextResource>() {
				public java.lang.Void exec(XtextResource resource) throws Exception {
					EObject selected = eObjectAtOffsetHelper.resolveElementAt(resource, selection.getOffset());
					if (selected instanceof XtendFunction){
						XtendFunction func = (XtendFunction) selected;
						if (editor.getEditorInput() instanceof FileEditorInput){
							FileEditorInput fileInput = (FileEditorInput) editor.getEditorInput();
							IContainer container = fileInput.getFile().getParent();
							String generatedTemplate = RunConfTemplateGenerator.generateTemplate(func, fileInput.getFile()).toString();
							InputStream inputStream = new ByteArrayInputStream(generatedTemplate.getBytes());
							IFile targetFile = container.getFile(org.eclipse.core.runtime.Path.fromPortableString(getRconfName(func, event, container)));
							if (targetFile.exists())
								targetFile.setContents(inputStream, true, true, null);
							else
								targetFile.create(inputStream, true, null);
							IEditorDescriptor desc = PlatformUI.getWorkbench().
							        getEditorRegistry().getDefaultEditor(targetFile.getName());
							IWorkbenchPage page = PlatformUI.getWorkbench().getActiveWorkbenchWindow().getActivePage();
							page.openEditor(new FileEditorInput(targetFile), desc.getId());
						}
					}
					return null;
				}
			});
		}
		return null;
	}
	
	private String getRconfName(XtendFunction func, ExecutionEvent event, IContainer container){
		String initial = func.getDeclaringType().getName() + "_" + func.getName();
		String actual = initial + ".rconf";
		int counter = 1;
		while (container.getFile(org.eclipse.core.runtime.Path.fromPortableString(actual)).exists()){
			actual = initial + "(" + counter++ + ").rconf";
		}
		InputDialog id = new InputDialog(HandlerUtil.getActiveShell(event), "Generate Run Configuration", "Enter the path for the new run configuration.", actual, new IInputValidator(){

			@Override
			public String isValid(String newText) {
				return null;
			}
			
		});
		id.setBlockOnOpen(true);
		id.open();
		return id.getValue();
	}

}
