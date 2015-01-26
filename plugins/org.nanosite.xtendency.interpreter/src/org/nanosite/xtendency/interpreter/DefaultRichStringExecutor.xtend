package org.nanosite.xtendency.interpreter

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
import org.eclipse.xtext.xbase.interpreter.impl.DefaultEvaluationResult
import org.eclipse.xtext.xbase.interpreter.IEvaluationResult
import org.nanosite.xtendency.interpreter.IRichStringExecutor
import org.nanosite.xtendency.interpreter.RichStringException

class DefaultRichStringExecutor extends AbstractRichStringPartAcceptor.ForLoopOnce implements IRichStringExecutor {

	protected IExpressionInterpreter interpreter
	protected val CancelIndicator indicator

	protected val contextStack = new Stack<IEvaluationContext>

	val sb = new StringBuilder

	new(IExpressionInterpreter interpreter, IEvaluationContext context, CancelIndicator indicator) {
		this.interpreter = interpreter
		contextStack.push(context)
		this.indicator = indicator
	}

	override getResult() {
		sb.toString
	}

	override acceptSemanticText(CharSequence text, /* @Nullable */ RichStringLiteral origin) {
		if (! ignoring) {
			if (origin == null)
				append(text.toString)
			else
				append(origin, text.toString)
		}
	}

	override acceptSemanticLineBreak(int charCount, RichStringLiteral origin, boolean controlStructureSeen) {
		if (! ignoring && controlStructureSeen) {
			if (origin == null)
				append("\n")
			else
				append(origin, "\n")
		}
	}
	
	override acceptTemplateText(CharSequence text, RichStringLiteral origin) {
		super.acceptTemplateText(text, origin)
	}
	
	override acceptTemplateLineBreak(int charCount, RichStringLiteral origin) {
		super.acceptTemplateLineBreak(charCount, origin)
	}

	static class IfThenElse {
		var boolean condition
		var boolean ignoring

		new(boolean condition) {
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

		new(JvmFormalParameter parameter) {
			this.parameter = parameter
			this.iter = null
		}

		new(JvmFormalParameter parameter, Iterator<?> iter) {
			this.parameter = parameter
			this.iter = iter
		}

		def isFirstIteration() {
			isFirst
		}

		def hasNext() {
			if (iter == null)
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
		val obj = eval(expression) as Iterable<?>
		if (obj == null) {
			System.err.println("ERROR: For-loop-expression evaluated to null")

			// ignore this for-loop			
			forLoopStack.push(new DefaultRichStringExecutor.ForLoop(parameter))
		} else {
			val iter = obj.iterator
			forLoopStack.push(new DefaultRichStringExecutor.ForLoop(parameter, iter))
		}
	}

	override forLoopHasNext(/* @Nullable */XExpression before, /* @Nullable */ XExpression separator,
		CharSequence indentation) {
		val desc = forLoopStack.peek
		if (desc.isFirst) {
			if (before != null) {
				append(before, "")
			}
		} else {

			// remove context of previous iteration from stack
			contextStack.pop
		}

		if (desc.hasNext) {
			if ((! desc.isFirst) && separator != null) {
				append(separator, "")
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

	override acceptEndFor(/* @Nullable */XExpression after, CharSequence indentation) {
		forLoopStack.pop
		if (after != null) {
			append(after, indentation)
		}
	}

	override acceptExpression(XExpression expression, CharSequence indentation) {
		append(expression, indentation)
	}

	def protected Object eval(XExpression expression) {
		val result = interpreter.evaluate(expression, contextStack.peek, indicator)
		if (result.exception != null) {
			System.err.println("ERROR during evaluation: " + result.exception.toString)
			throw new RichStringException(result.exception)
		} else {
			result.result
		}
	}

	def protected void append(String str) {
		sb.append(str)
	}

	def protected void append(XExpression input, CharSequence indentation) {
		val obj = eval(input)
		val toAppend = obj.toString
		val lines = toAppend.split("\\n")
		val result = 
		'''«lines.head»«IF lines.size > 1»«"\n"»«ENDIF»«FOR l : lines.tail SEPARATOR "\n"»«indentation»«l»«ENDFOR»'''
		
		sb.append(result)
	}

	def protected void append(RichStringLiteral lit, String str) {
		sb.append(str)
	}
}
