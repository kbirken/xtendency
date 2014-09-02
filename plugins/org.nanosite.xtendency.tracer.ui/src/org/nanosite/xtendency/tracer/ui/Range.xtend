package org.nanosite.xtendency.tracer.ui

class Range {
	int first
	int end
	
	new(int first, int end){
		this.first = first
		this.end = end
	}
	
	def getFirst(){
		return first
	}
	
	def getEnd(){
		return end
	}
	
	def boolean contains(int index){
		index >= first && index < end
	}
	
	def boolean overlaps(Range other){
		#[first, end-1].exists[other.contains(it)] || #[other.first, other.end-1].exists[contains]
	}
}