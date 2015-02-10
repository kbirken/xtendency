package org.nanosite.xtendency.interpreter

import java.util.List
import org.eclipse.xtend.core.xtend.RichStringLiteral
import org.eclipse.xtext.xbase.XExpression
import org.eclipse.xtend.core.xtend.RichStringIf
import org.eclipse.xtend.core.xtend.RichStringForLoop
import org.eclipse.xtend.core.xtend.RichStringElseIf
import java.util.ArrayList
import org.eclipse.emf.ecore.EObject

class RichStringLinePart<T> {
	private T source

	new(T source) {
		this.source = source
	}

	def getSource() {
		source
	}
}

class LiteralPart extends RichStringLinePart<RichStringLiteral> {
	private String value

	new(String value, RichStringLiteral source) {
		super(source)
		this.value = value
	}

	def getValue() {
		value
	}

	override toString() {
		value
	}

	def boolean isAllWhitespace() {
		for (var i = 0; i < value.length; i++) {
			if (!Character.isWhitespace(value.charAt(i)))
				return false
		}
		return true
	}

}

class IfPart extends RichStringLinePart<RichStringIf> {

	new(RichStringIf source) {
		super(source)
	}

	override toString() {
		"«IF (...)»"
	}

}

class ElseIfPart extends RichStringLinePart<RichStringIf> {
	
	private RichStringElseIf elseIf

	new(RichStringIf source, RichStringElseIf elseIf) {
		super(source)
		this.elseIf = elseIf
	}

	override toString() {
		"«ELSEIF (...)»"
	}
	
	def getElseIf(){
		elseIf
	}

}

class ElsePart extends RichStringLinePart<RichStringIf> {

	new(RichStringIf source) {
		super(source)
	}

	override toString() {
		"«ELSE»"
	}

}

class EndIfPart extends RichStringLinePart<RichStringIf> {

	new(RichStringIf source) {
		super(source)
	}

	override toString() {
		"«ENDIF»"
	}

}

class ForPart extends RichStringLinePart<RichStringForLoop> {

	new(RichStringForLoop source) {
		super(source)
	}

	override toString() {
		"«FOR (...)»"
	}

}

class EndForPart extends RichStringLinePart<RichStringForLoop> {

	new(RichStringForLoop source) {
		super(source)
	}

	override toString() {
		"«ENDFOR»"
	}

}

class ExpressionPart extends RichStringLinePart<XExpression> {

	new(XExpression source) {
		super(source)
	}

	override toString() {
		source.toString
	}

}

class RichStringLine {

	// all expressions in the line
	// should not contain a linebreak at the end
	private List<RichStringLinePart<? extends XExpression>> expressions = new ArrayList

	// ignored whitespace is calculated by richstringlinecreator
	// then ignoreWhitespace is called and expressions are divided into
	private String originalWhitespace
	private String ignoredWhitespace
	private String outputWhitespace
	private List<RichStringLinePart<? extends XExpression>> outputExpressions

	// then evaluate is called
	def boolean isIgnored() {
		false
	}

	def getExpressions() {
		expressions
	}

	def getOutputWhitespace() {
		outputWhitespace
	}

	def getOutputExpressions() {
		outputExpressions
	}

	def clean() {
		expressions.removeAll(expressions.filter[e|e instanceof LiteralPart && (e as LiteralPart).value == ""])
	}

	// returns the indentation of the line
	def String getOriginalWhitespace() {
		if (originalWhitespace == null) {
			var result = ""
			for (expr : expressions) {
				if (expr instanceof LiteralPart) {
					if (expr.isAllWhitespace) {
						result += expr.value
					} else {
						for (var i = 0; i < expr.value.length; i++) {
							if (Character.isWhitespace(expr.value.charAt(i)))
								result += expr.value.charAt(i)
							else
								return result
						}
					}
				} else {
					return result
				}
			}
			originalWhitespace = result
			result
		} else {
			originalWhitespace
		}
	}

	def void ignoreWhitespace(String toIgnore) {
		ignoredWhitespace = toIgnore
		outputWhitespace = getOriginalWhitespace.removeAtBeginning(toIgnore, isAllWhitespace)
		outputExpressions = new ArrayList
		if (!expressions.empty && expressions.head instanceof LiteralPart){
			val startLiteral = expressions.head as LiteralPart
			outputExpressions += new LiteralPart(startLiteral.value.removeAtBeginning(toIgnore, isAllWhitespace), startLiteral.source)
			outputExpressions += expressions.tail
		}else{
			outputExpressions = expressions
		}
	}

	def String removeAtBeginning(String original, String toRemove, boolean emptyOnError) {
		if (toRemove.empty)
			return original
		val result = new StringBuilder
		var opos = 0
		var rpos = 0
		while (rpos < toRemove.length) {
			if (opos >= original.length) {

				// inconsistent indentation
				return if (emptyOnError) "" else original
			} else if (original.charAt(opos) == toRemove.charAt(rpos)) {
				rpos++
				opos++
			} else {
				if (!Character.isWhitespace(original.charAt(opos))) {

					// inconsistent indentation
					return if (emptyOnError) "" else original
				} else {
					result.append(original.charAt(opos++))
				}
			}
		}
		result.append(original.substring(opos))
		result.toString
	}

	def boolean isAllWhitespace() {
		if (expressions.forall[it instanceof LiteralPart]) {
			expressions.forall[(it as LiteralPart).allWhitespace]
		} else {
			false
		}
	}

	override toString() {
		val result = new StringBuilder
		val outExpressions = outputExpressions ?: expressions
		for (e : outExpressions) {
			result.append(e.toString)
		}

		result.toString
	}

}
