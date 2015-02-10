package org.nanosite.xtendency.interpreter

import java.util.ArrayList
import java.util.List
import org.eclipse.xtend.core.xtend.RichString
import org.eclipse.xtend.core.xtend.RichStringForLoop
import org.eclipse.xtend.core.xtend.RichStringIf
import org.eclipse.xtend.core.xtend.RichStringLiteral
import org.eclipse.xtext.xbase.XBlockExpression
import org.eclipse.xtext.xbase.XExpression
import java.util.HashSet
import java.util.HashMap
import java.util.Map

class MutablePair<K, V> {
	private K k
	private V v

	new(K k, V v) {
		this.k = k
		this.v = v
	}

	def getKey() {
		k
	}

	def getValue() {
		v
	}

	def setKey(K k) {
		this.k = k
	}

	def setValue(V v) {
		this.v = v
	}
}

class RichStringLineCreator {
	
	protected Map<RichStringLiteral, List<LiteralPart>> literalMappings

	def Pair<List<RichStringLine>, Map<RichStringLiteral, List<LiteralPart>>> getLines(RichString rs) {
		literalMappings = new HashMap
		val initial = new ArrayList<RichStringLine>
		initial += new RichStringLine
		initial.addToLines(rs)
		initial.forEach[clean]
		initial.setIndentation 
		initial -> literalMappings
	}

	def setIndentation(List<RichStringLine> lines) {
		var String ignoredIndentation = null
		for (line : lines) {
			if (!line.isAllWhitespace) {
				ignoredIndentation = ignoredIndentation.getCommonWhitespace(line.originalWhitespace)
			}
		}
		val baseIgnored = ignoredIndentation ?: ""
		val ignoreInfo = new ArrayList(lines.map[new MutablePair(it, baseIgnored)])
		ignoreInfo.ignoreSpecialIndentation(null)
		for (l : ignoreInfo){
			l.key.ignoreWhitespace(l.value)
		}
	}

	def void ignoreSpecialIndentation(List<MutablePair<RichStringLine, String>> lines, Object ignoreSourceUntil) {	
		if (lines.length > 4 && lines.get(3).key.toString.contains("number"))
			println("!!")
			
		val sections = new ArrayList<Pair<Object, List<MutablePair<RichStringLine, String>>>>
		var Pair<Object, List<MutablePair<RichStringLine, String>>> openSection = null
		var ignoreFound = if(ignoreSourceUntil == null) true else false
		for (line : lines) {
			for (p : line.key.expressions) {
				if (p instanceof IfPart || p instanceof ForPart) {
					if (ignoreFound && openSection == null) {
						openSection = p.source -> new ArrayList
					} else if (p.source == ignoreSourceUntil) {
						ignoreFound = true
					} else {
						// do nothing, this should be ignored
					}
				} else if (p instanceof EndIfPart || p instanceof EndForPart) {
					if (openSection != null && openSection.key == p.source) {
						if (openSection.value.empty){
							openSection = null
						}else{
							openSection.value += line
							sections.add(0, p.source -> openSection.value)
							openSection = null
						}
					}
				} else if (p instanceof ElseIfPart || p instanceof ElsePart) {
					if (ignoreFound && openSection != null && openSection.key == p.source) {
						if (openSection.value.empty){
							// change nothing
						}else{
							openSection.value += line
							sections.add(0, p.source -> openSection.value)
							openSection = p.source -> new ArrayList
						}	
					}else if (!ignoreFound && p.source === ignoreSourceUntil){
						ignoreFound = true
					}else {
						//do nothing, this should be ignored
					}
				}
			}
			if (openSection != null) {
				openSection.value += line
			}
		}
		for (s : sections) {
			s.key.adjustIndentation(s.value)
		}
	}

	def void adjustIndentation(Object source, List<MutablePair<RichStringLine, String>> lines) {
		// do stuff
		val firstLineLast = lines.head.key.expressions.last
		val lastLineFirst = if(lines.last.key.expressions.head instanceof LiteralPart &&
				(lines.last.key.expressions.head as LiteralPart).allWhitespace) lines.last.key.expressions.get(1) else lines.
				last.key.expressions.head

		if (source instanceof RichStringForLoop) {
			if (firstLineLast instanceof ForPart && firstLineLast.source == source) {
				if (lastLineFirst instanceof EndForPart && lastLineFirst.source == source) {
					val basisIndentation = lines.head.key.originalWhitespace
					basisIndentation.ignoreDifference(lines)
				}
			}
		} else if (source instanceof RichStringIf) {
			if ((firstLineLast instanceof IfPart || firstLineLast instanceof ElseIfPart ||
				firstLineLast instanceof ElsePart) && firstLineLast.source == source) {
				if ((lastLineFirst instanceof EndIfPart || lastLineFirst instanceof ElsePart ||
					lastLineFirst instanceof ElseIfPart) && lastLineFirst.source == source) {
						val basisIndentation = lines.head.key.originalWhitespace
						basisIndentation.ignoreDifference(lines)
				}
			}
		}

		// do the same for any inner control structures
		lines.ignoreSpecialIndentation(source)
	}

	def void ignoreDifference(String basisIndentation, List<MutablePair<RichStringLine, String>> lines) {
		var String ignoredIndent = null

		for (var i = 1; i < lines.size - 1; i++) {
			val difference = lines.get(i).key.originalWhitespace.removeAtBeginning(basisIndentation)
			if (difference == null) {
				// incorrect indentation
			} else {
				ignoredIndent = ignoredIndent.getCommonWhitespace(difference)
			}
		}
		val resultIgnored = ignoredIndent ?: ""
		for (var i = 1; i < lines.size - 1; i++) {
			lines.get(i).value = lines.get(i).value + resultIgnored
		}
	}

	def String removeAtBeginning(String lineIndent, String basisIndent) {
		if (!lineIndent.startsWith(basisIndent))
			return null
		return lineIndent.substring(basisIndent.length)
	}

	def String getCommonWhitespace(String current, String nw) {
		if (current == null)
			nw
		else {
			val result = new StringBuilder
			for (var i = 0; i < Math.min(current.length, nw.length); i++) {
				if (current.charAt(i) == nw.charAt(i))
					result.append(current.charAt(i))
				else {
					return result.toString
				}
			}
			result.toString
		}
	}
	
	def void addPart(RichStringLiteral source, LiteralPart part){
		if (literalMappings.containsKey(source)){
			literalMappings.get(source) += part
		}else{
			val result = new ArrayList
			result += part
			literalMappings.put(source, result)
		}
	}

	def dispatch void addToLines(List<RichStringLine> lines, RichStringLiteral expr) {
		val split = expr.value.splitCorrectly('\n')
		if (split.size > 1) {
			for (var i = 0; i < split.length; i++) {
				if (!split.get(i).empty){
					val newPart = new LiteralPart(split.get(i), expr)
					lines.last.expressions += newPart
					expr.addPart(newPart)
				}
				if (i < split.length - 1) {
					lines += new RichStringLine
				}
			}
		} else {
			if (!expr.value.empty){
				val newPart = new LiteralPart(expr.value, expr)
				lines.last.expressions += newPart
				expr.addPart(newPart)
			}
		}
	}

	def dispatch void addToLines(List<RichStringLine> lines, RichStringForLoop expr) {
		lines.last.expressions += new ForPart(expr)
		lines.addToLines(expr.eachExpression)
		lines.last.expressions += new EndForPart(expr)
	}

	def dispatch void addToLines(List<RichStringLine> lines, RichStringIf expr) {
		lines.last.expressions += new IfPart(expr)
		lines.addToLines(expr.then)
		for (ei : expr.elseIfs) {
			lines.last.expressions += new ElseIfPart(expr, ei)
			lines.addToLines(ei.then)
		}
		if (expr.^else != null) {
			lines.last.expressions += new ElsePart(expr)
			lines.addToLines(expr.^else)
		}
		lines.last.expressions += new EndIfPart(expr)
	}

	def dispatch void addToLines(List<RichStringLine> lines, RichString expr) {
		for (e : expr.expressions) {
			lines.addToLines(e)
		}
	}

	def dispatch void addToLines(List<RichStringLine> lines, XExpression expr) {
		lines.last.expressions += new ExpressionPart(expr)
	}

	def static List<String> splitCorrectly(CharSequence str, char delimiter) {
		val result = new ArrayList
		var currentSegment = ""
		for (var i = 0; i < str.length; i++) {
			if (str.charAt(i) == delimiter) {
				result += currentSegment
				currentSegment = ""
			} else {
				currentSegment += str.charAt(i)
			}
		}
		result += currentSegment
		result
	}
}
