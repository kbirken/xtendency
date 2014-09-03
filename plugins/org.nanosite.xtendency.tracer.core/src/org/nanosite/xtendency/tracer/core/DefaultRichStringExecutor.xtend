package org.nanosite.xtendency.tracer.core

import java.util.Iterator
import java.util.Stack
import org.eclipse.xtend.core.richstring.AbstractRichStringPartAcceptor
import org.eclipse.xtend.core.xtend.RichStringLiteral
import org.eclipse.xtext.common.types.JvmFormalParameter
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import org.eclipse.xtext.xbase.interpreter.IExpressionInterpreter

class DefaultRichStringExecutor extends AbstractRichStringPartAcceptor.ForLoopOnce implements IRichStringExecutor {
	
	val IExpressionInterpreter interpreter
	val CancelIndicator indicator

	val contextStack = new Stack<IEvaluationContext>
	
	val sb = new StringBuilder
	
	new (IExpressionInterpreter interpreter, IEvaluationContext context, CancelIndicator indicator) {
		this.interpreter = interpreter
		contextStack.push(context)
		this.indicator = indicator
	}
	
	override getResult() {
		sb.toString
	}

	override acceptSemanticText(CharSequence text, /* @Nullable */ RichStringLiteral origin) {
		if (! ignoring)
			append(text, origin)
	}
	
	override acceptSemanticLineBreak(int charCount, RichStringLiteral origin, boolean controlStructureSeen) {
		// TODO: what's charCount?
		if (! ignoring)
			append("\n", origin)
	}


	static class IfThenElse {
		var boolean condition
		var boolean ignoring
		
		new (boolean condition) {
			update(condition)
		}
		
		def update(boolean condition) {
			this.condition = condition
			this.ignoring = ! condition
		}
	}
	
	val ifStack = new Stack<DefaultRichStringExecutor.IfThenElse>
	
	override acceptIfCondition(XExpression condition) {
		val cond = eval(condition) as Boolean
		ifStack.push(new DefaultRichStringExecutor.IfThenElse(cond))
	}

	def private ignoring() {
		if (ifStack.isEmpty)
			false
		else
			ifStack.peek.ignoring
	}

	override acceptElseIfCondition(XExpression condition) {
		val desc = ifStack.peek
		if (desc.condition) {
			// previous condition was true, ignore all following
			desc.ignoring = true
		} else {
			// evaluate next condition
			val cond = eval(condition) as Boolean
			desc.update(cond)
		}
	}

	override acceptElse() {
		val desc = ifStack.peek
		desc.ignoring = desc.condition
	}

	override acceptEndIf() {
		ifStack.pop
	}


	static class ForLoop {
		val JvmFormalParameter parameter
		
		// if iter==null we just ignore the loop body and skip to the end of loop
		val Iterator<?> iter
		
		var isFirst = true

		new (JvmFormalParameter parameter) {
			this.parameter = parameter
			this.iter = null
		}
		
		new (JvmFormalParameter parameter, Iterator<?> iter) {
			this.parameter = parameter
			this.iter = iter
		}
		
		def isFirstIteration() {
			isFirst
		}
		
		def hasNext() {
			if (iter==null)
				false
			else
				iter.hasNext
		}
		
		def getParamName() {
			QualifiedName.create(parameter.getQualifiedName('$'))
		}

		def next() {
			isFirst = false
			iter.next
		}
	}
	

	val forLoopStack = new Stack<DefaultRichStringExecutor.ForLoop>
	
	override acceptForLoop(JvmFormalParameter parameter, /* @Nullable */ XExpression expression) {
		val iter = (eval(expression) as Iterable<?>).iterator
		forLoopStack.push(new DefaultRichStringExecutor.ForLoop(parameter, iter))
	}

	override forLoopHasNext(/* @Nullable */ XExpression before, /* @Nullable */ XExpression separator, CharSequence indentation) {
		val desc = forLoopStack.peek
		if (desc.isFirst) {
			if (before!=null) {
				val b = eval(before)
				// TODO: error checks
				append(b as CharSequence, before)
			}
		} else {
			// remove context of previous iteration from stack
			contextStack.pop
		}
		
		if (desc.hasNext) {
			if ((! desc.isFirst) && separator!=null) {
				val b = eval(separator)
				// TODO: error checks
				append(b as CharSequence, separator)
			}

			// clone context for next iteration and add loop variable
			val newContext = contextStack.peek.fork
			newContext.newValue(desc.paramName, desc.next)
			contextStack.push(newContext)
			true
		} else {
			false
		}
	}

	override acceptEndFor(/* @Nullable */ XExpression after, CharSequence indentation) {
		forLoopStack.pop
		if (after!=null) {
			val b = eval(after)
			// TODO: error checks
			append(b as CharSequence, after)
		}
	}


	override acceptExpression(XExpression expression, CharSequence indentation) {
		val obj = eval(expression)
		if (obj!=null)
			append(obj.toString, expression)
		else
			System.err.println("ERROR: Expression evaluated to null in RichString!")
	}

	def private eval(XExpression expression) {
		val result = interpreter.evaluate(expression, contextStack.peek, indicator)
		
		// TODO: error handling
		result.result
	}
	
	def protected void append(CharSequence str, XExpression input) {
		if (str.length!=0) {
			sb.append(str)
		}
	}
}

