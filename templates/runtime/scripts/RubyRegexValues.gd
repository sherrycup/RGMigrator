extends RefCounted
## Ruby 1.8 regexp flags and UTF-8 byte offsets at the migration boundary.
## RegExp objects remain value descriptors; the Godot RegEx is transient.
static func compile(pattern: String,flags: String) -> Dictionary:
	for flag in flags:
		if flag not in ["i","m","x","o"]: return {"ok":false,"message":"正则标志尚未支持："+flag}
	var regex=RegEx.new()
	# Ruby's default anchors are per-line; Ruby /m enables dot-all.
	var prefix="(?m)"+("(?i)" if flags.contains("i") else "")+("(?s)" if flags.contains("m") else "")+("(?x)" if flags.contains("x") else "")
	if regex.compile(prefix+pattern)!=OK: return {"ok":false,"message":"正则无法编译："+pattern}
	return {"ok":true,"regex":regex}

static func match_value(descriptor: Dictionary,value: String) -> Dictionary:
	var compiled=compile(descriptor.source,descriptor.flags)
	if not compiled.ok: return compiled
	var found: RegExMatch=compiled.regex.search(value)
	if found==null: return {"ok":true,"data":null}
	var groups: Array=[]; var starts: Array=[]
	for i in found.get_group_count()+1:
		var start=found.get_start(i)
		groups.append(found.get_string(i) if start>=0 else null)
		starts.append(value.left(start).to_utf8_buffer().size() if start>=0 else null)
	return {"ok":true,"data":{"__ruby_match":true,"groups":groups,"starts":starts,"pre":value.left(found.get_start()),"post":value.substr(found.get_end()),"source":value}}

static func split(descriptor: Dictionary,value: String,limit: int=0) -> Dictionary:
	var compiled=compile(descriptor.source,descriptor.flags)
	if not compiled.ok: return compiled
	if limit==1: return {"ok":true,"value":[value]}
	var rows: Array=[]; var cursor=0; var pieces=0
	for found in compiled.regex.search_all(value):
		if found.get_start()==0 and found.get_end()==0: continue
		if limit>0 and pieces>=limit-1: break
		rows.append(value.substr(cursor,found.get_start()-cursor)); pieces+=1
		for i in range(1,found.get_group_count()+1):
			if found.get_start(i)>=0: rows.append(found.get_string(i))
		cursor=found.get_end()
	rows.append(value.substr(cursor))
	if limit==0:
		while not rows.is_empty() and rows[-1]=="": rows.pop_back()
	return {"ok":true,"value":rows}
