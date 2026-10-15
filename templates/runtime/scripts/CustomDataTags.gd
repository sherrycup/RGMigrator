extends RefCounted
## Keep the raw token even when its eventual gameplay meaning is unknown.
static func parse(name: String) -> Array:
	var result: Array=[]; var parts=name.split(":")
	var matcher=RegEx.new(); matcher.compile("^([A-Za-z%]+)([-+]?[0-9]+(?:\\.[0-9]+)?)$")
	for i in range(1,parts.size()):
		var found=matcher.search(parts[i]); var value: Variant=null
		if found!=null:
			var raw=found.get_string(2)
			value=raw if abs(float(raw))>9007199254740991 else float(raw)
		result.append({"raw":parts[i],"key":found.get_string(1) if found!=null else "","value":value,"behavior_stage":"0.45"})
	return result
