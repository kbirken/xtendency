package org.nanosite.xtendency.tracer.richstring

@Data class RichStringOutputLocation{
	int offset
	int length
	String str
	
	override toString() {
		"[" + offset + "/" + length + " '" + str.replace("\n", "\\n") + "']"
	}
}