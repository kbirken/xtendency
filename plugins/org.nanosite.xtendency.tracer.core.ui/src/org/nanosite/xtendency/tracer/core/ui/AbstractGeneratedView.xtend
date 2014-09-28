package org.nanosite.xtendency.tracer.core.ui

import org.eclipse.ui.part.ViewPart
import org.eclipse.ui.ISelectionListener
import org.eclipse.core.resources.IResourceChangeListener

abstract class AbstractGeneratedView extends ViewPart implements IGeneratedView, IResourceChangeListener, ISelectionListener {
	
}