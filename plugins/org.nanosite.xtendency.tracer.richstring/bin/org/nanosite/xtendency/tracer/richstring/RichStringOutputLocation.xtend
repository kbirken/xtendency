package org.nanosite.xtendency.tracer.richstring

class RichStringOutputLocation{
	int offset
	int length
	String str
	
	new(int offset, int length, String str){
		this.offset = offset
		this.length = length
		this.str = str
	}
	
	def int getOffset(){
		offset
	}
	
	def void setOffset(int offset){
		this.offset = offset
	}
	
	def int getLength(){
		length
	}
	
	override toString() {
		"[" + offset + "/" + length + " '" + str.replace("\n", "\\n") + "']"
	}
}