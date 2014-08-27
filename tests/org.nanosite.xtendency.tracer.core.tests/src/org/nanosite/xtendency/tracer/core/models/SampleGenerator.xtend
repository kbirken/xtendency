package org.nanosite.xtendency.tracer.core.models

class SampleGenerator {
	
	def static String generate(String who, boolean isHello) {
		if (isHello) {
			"Hello " +
			who +
			"!"
		} else {
			var result = ""
			for(i : 1..10)
				result = result + i + " "
			result
		}
	}

}
