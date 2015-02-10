package org.nanosite.xtendency.interpreter

import java.util.List
import org.eclipse.xtext.xbase.interpreter.IEvaluationContext
import java.util.Map
import org.eclipse.xtend.core.xtend.RichStringLiteral
import org.eclipse.xtend.core.xtend.RichString
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.xbase.XExpression
import java.util.HashMap
import java.util.ArrayList
import java.util.Arrays
import org.eclipse.emf.ecore.EObject
import java.util.Stack
import org.eclipse.xtext.naming.QualifiedName

class RichStringResult {
	protected List<List<String>> lines

}

class RichStringEvaluator {
	protected IInterpreterAccess interpreter

	protected Map<RichStringLiteral, List<LiteralPart>> literalMappings
	protected List<RichStringLine> lines
	protected int currentLine
	protected int currentExpression
	protected boolean done = false
	protected Map<XExpression, List<? extends Object>> evalInfo = new HashMap
	protected Stack<IEvaluationContext> contextStack = new Stack
	protected List<String> result = new ArrayList
	protected List<String> lineInProgress

	// every method returns the string corresponding to its input expression
	// but we also build a version of the whole string in some member
	// so that we can decide things like "is the current line empty"
	// and build the strings for individual expressions accordingly
	// god i hope this works
	new(IInterpreterAccess access, List<RichStringLine> lines, Map<RichStringLiteral, List<LiteralPart>> literalMappings) {
		this.interpreter = access
		this.literalMappings = literalMappings
		this.currentLine = 0
		this.currentExpression = -1
		this.lines = lines
	}

	def String evaluateLines(IEvaluationContext context) {
		contextStack.push(context)
		lineInProgress = new ArrayList
		step("", true)
		while (!done) {
			val indentHere = lines.get(currentLine).outputWhitespace
			val skipIfEmpty = !lines.get(currentLine).hasNonWhitespaceText && currentLine != lines.size - 1
			val expr = lines.get(currentLine).outputExpressions.get(currentExpression)
			val result = expr.evaluateInLine
			lineInProgress += result
			step(indentHere, skipIfEmpty)
		}
		result.reduce[p1, p2|p1 + "\n" + p2] ?: ""
	}

	def boolean hasNonWhitespaceText(RichStringLine line) {
		var result = false
		for (p : line.outputExpressions) {
			if (p instanceof LiteralPart) {
				result = result || !p.value.allWhitespace
			}
		}
		result
	}

	def List<String> indentAndSeparate(List<String> line, String indentation) {
		val result = new StringBuilder
		for (part : line)
			result.append(part)

//		val resultList = RichStringLineCreator.splitCorrectly(result.toString.replaceAll("\\n", "\n" + indentation), '\n')
		val resultList = result.toString.replaceAll("\\n", "\n" + indentation).split('\\n')
		
		if (resultList.size > 1 && resultList.last.allWhitespace) resultList.subList(0, resultList.size - 1) else resultList
	}

	def void newLine(String indentation) {
		result += lineInProgress.indentAndSeparate(indentation)
		lineInProgress = new ArrayList
	}

	def void newLineIfNotEmpty(String indentation) {
		var empty = true
		for (part : lineInProgress) {
			empty = empty && part.allWhitespace
		}
		if (empty) {
			lineInProgress = new ArrayList
		} else {
			newLine(indentation)
		}
	}

	def boolean isAllWhitespace(String s) {
		for (var i = 0; i < s.length; i++) {
			if (!Character.isWhitespace(s.charAt(i)))
				return false
		}
		return true
	}

	def dispatch String evaluateInLine(LiteralPart p) {
		p.value
	}

	def dispatch String evaluateInLine(ExpressionPart p) {
		interpreter.evaluate(p.source, contextStack.peek, CancelIndicator.NullImpl).toString
	}

	def dispatch String evaluateInLine(IfPart p) {
		val condition = p.source.^if
		val condValue = interpreter.evaluate(condition, contextStack.peek, CancelIndicator.NullImpl) as Boolean
		if (condValue) {
			evalInfo.put(p.source, new ArrayList(#[Boolean.TRUE]))
			""
		} else {
			evalInfo.put(p.source, new ArrayList(#[Boolean.FALSE]))
			p.source.stepTillSource
			""
		}
	}

	def dispatch String evaluateInLine(ElseIfPart p) {
		val previouslyTrue = (evalInfo.get(p.source) as List<Boolean>).exists[it]
		if (!previouslyTrue) {
			val condition = p.elseIf.^if
			val condValue = interpreter.evaluate(condition, contextStack.peek, CancelIndicator.NullImpl) as Boolean
			if (condValue) {
				(evalInfo.get(p.source) as List<Boolean>) += Boolean.TRUE
				""
			} else {
				(evalInfo.get(p.source) as List<Boolean>) += Boolean.FALSE
				p.source.stepTillSource
				""
			}
		} else {
			p.source.stepTillSource
			""
		}
	}

	def dispatch String evaluateInLine(ElsePart p) {
		val previouslyTrue = (evalInfo.get(p.source) as List<Boolean>).exists[it]
		if (!previouslyTrue) {
			""
		} else {
			p.source.stepTillSource
			""
		}
	}

	def dispatch String evaluateInLine(EndIfPart p) {
		evalInfo.remove(p.source)
		""
	}

	def dispatch String evaluateInLine(ForPart p) {
		val visitedBefore = evalInfo.containsKey(p.source)
		if (visitedBefore) {
			val iterations = evalInfo.get(p.source)
			if (iterations.empty) {
				p.source.stepTillSource
				""
			} else {
				val current = iterations.head
				val newContext = contextStack.peek.fork
				newContext.newValue(QualifiedName.create(p.source.declaredParam.name), current)
				contextStack.push(newContext)
				evalInfo.put(p.source, iterations.tail.toList)
				""
			}
		} else {
			val forValue = new ArrayList(
				(interpreter.evaluate(p.source.forExpression, contextStack.peek, CancelIndicator.NullImpl) as Iterable<?>).
					toList)
			evalInfo.put(p.source, forValue)
			currentExpression--
			if (p.source.before != null) {
				val beforeValue = interpreter.evaluate(p.source.before, contextStack.peek, CancelIndicator.NullImpl)
				beforeValue?.toString ?: "null"
			} else {
				""
			}
		}
	}

	def dispatch String evaluateInLine(EndForPart p) {
		val restIterations = evalInfo.get(p.source)
		contextStack.pop
		if (restIterations.empty) {
			evalInfo.remove(p.source)
			if (p.source.after != null) {
				val afterValue = interpreter.evaluate(p.source.after, contextStack.peek, CancelIndicator.NullImpl)
				afterValue?.toString ?: "null"
			} else {
				""
			}
		} else {
			p.source.backTillSource
			if (p.source.separator != null) {
				val separatorValue = interpreter.evaluate(p.source.separator, contextStack.peek,
					CancelIndicator.NullImpl)
				separatorValue?.toString ?: "null"
			} else {
				""
			}
		}
	}

	def void stepImplicitly() {
		step(null, true)
	}

	def void step(String indentation, boolean skipIfEmpty) {
		currentExpression++
		if (currentExpression >= lines.get(currentLine).outputExpressions.size) {
			currentExpression = 0
			currentLine++
			startNewLine(indentation, skipIfEmpty)
			if (currentLine >= lines.size) {
				done = true
			}
			while (!done && currentExpression >= lines.get(currentLine).outputExpressions.size) {
				currentLine++
				startNewLine(indentation, false)
				if (currentLine >= lines.size) {
					done = true
				}
			}
		}
	}

	def RichStringLinePart<? extends EObject> getCurrentPart() {
		lines.get(currentLine).outputExpressions.get(currentExpression)
	}

	def void stepTillSource(EObject source) {
		stepImplicitly
		while (!done && currentPart.source !== source) {
			stepImplicitly
		}
		currentExpression--
	}

	def void backTillSource(EObject source) {
		currentExpression--
		if (currentExpression < 0) {
			currentLine--
			currentExpression = lines.get(currentLine).outputExpressions.size - 1
		}
		while (currentPart.source !== source) {
			currentExpression--
			if (currentExpression < 0) {
				currentLine--
				currentExpression = lines.get(currentLine).outputExpressions.size - 1
			}
		}
		currentExpression--
	}

	def void startNewLine(String indentation, boolean skipIfEmpty) {
		if (skipIfEmpty) {
			newLineIfNotEmpty(indentation)
		} else {
			newLine(indentation)
		}
	}
}
