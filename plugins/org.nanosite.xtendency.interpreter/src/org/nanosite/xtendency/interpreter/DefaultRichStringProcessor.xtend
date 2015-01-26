package org.nanosite.xtendency.interpreter

import org.eclipse.xtend.core.richstring.RichStringProcessor
import org.eclipse.xtend.core.xtend.RichString
import org.eclipse.xtend.core.richstring.IRichStringPartAcceptor
import org.eclipse.xtend.core.richstring.IRichStringIndentationHandler
import org.eclipse.xtend.core.xtend.RichStringIf
import org.eclipse.xtend.core.xtend.RichStringElseIf
import com.google.inject.Inject

class DefaultRichStringProcessor extends RichStringProcessor {
		
	override process(RichString richString, IRichStringPartAcceptor acceptor, IRichStringIndentationHandler indentationHandler) {
		val processedRichString = new DefaultProcessedRichStringBuilder(acceptor as DefaultRichStringExecutor).processRichString(richString);
		val implementation = new Implementation(acceptor, indentationHandler);
		implementation.doSwitch(processedRichString);
	}
	
}

class DefaultProcessedRichStringBuilder extends RichStringProcessor$ProcessedRichStringBuilder {
	private DefaultRichStringExecutor executor
	
	new (DefaultRichStringExecutor executor){
		this.executor = executor	
	}
	
	override caseRichStringIf(RichStringIf object) {
		// evaluate condition(s)
		// and put in only one segment
		// on which we probably just call doSwitch ??
		val firstCond = executor.interpreter.evaluate(object.^if, executor.contextStack.head, executor.indicator)
		if (firstCond.result as Boolean){
			return doSwitch(object.then)
		}else{
			for (eif : object.elseIfs){
				val cond = executor.interpreter.evaluate(eif.^if, executor.contextStack.head, executor.indicator)
				if (cond.result as Boolean){
					return doSwitch(eif.then)
				}
			}
			if (object.^else != null){
				return doSwitch(object.^else)
			}
			return Boolean.TRUE
		}
		
//		IfConditionStart start = factory.createIfConditionStart();
//			start.setRichStringIf(object);
//			addToCurrentLine(start);
//			doSwitch(object.getThen());
//			for (RichStringElseIf elseIf : object.getElseIfs()) {
//				ElseIfCondition elseIfStart = factory.createElseIfCondition();
//				elseIfStart.setIfConditionStart(start);
//				elseIfStart.setRichStringElseIf(elseIf);
//				addToCurrentLine(elseIfStart);
//				doSwitch(elseIf.getThen());
//			}
//			if (object.getElse() != null) {
//				ElseStart elseStart = factory.createElseStart();
//				elseStart.setIfConditionStart(start);
//				addToCurrentLine(elseStart);
//				doSwitch(object.getElse());
//			}
//			EndIf end = factory.createEndIf();
//			end.setIfConditionStart(start);
//			addToCurrentLine(end);
//			return Boolean.TRUE;
	}
	
	override caseRichStringElseIf(RichStringElseIf object) {
		super.caseRichStringElseIf(object)
	}
	
}