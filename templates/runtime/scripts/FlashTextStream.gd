extends RefCounted
## 0270 UTF-8 text blocks. Original filenames resolve in exported legacy/extras.
const END_TEXT="\\~\\/[END]"
var file_name=""
var line_label=""
var is_open=false
var lines: PackedStringArray=[]
var cursor=0
var failure=""

func open(name: String,label: String="",reload: bool=false) -> bool:
	failure=""
	var relative=name.replace("\\","/")
	if relative.is_empty() or relative.begins_with("/") or relative.contains(":"):
		close(); failure="文本流路径必须是原工程相对路径。"; return false
	for part in relative.split("/"):
		if part in ["",".",".."]: close(); failure="文本流路径含无效目录。"; return false
	if name!=file_name or not is_open or reload:
		close()
		var path="res://legacy/extras/"+relative+".txt"
		if not FileAccess.file_exists(path): file_name=""; line_label=""; lines=[]; cursor=0; return false
		var file=FileAccess.open(path,FileAccess.READ)
		if file==null: failure="文本流无法读取："+name; return false
		var raw=file.get_as_text(); lines=[]
		# readlines preserves newlines; CRLF remains accepted as a label boundary.
		for line in raw.split("\n",true): lines.append(line+"\n")
		if raw.ends_with("\n"): lines.resize(lines.size()-1)
		elif not lines.is_empty(): lines[-1]=lines[-1].trim_suffix("\n")
		file_name=name; cursor=0; is_open=true
		_seek(label); line_label=label
	elif label!=line_label: _seek(label); line_label=label
	return true

func close() -> void: is_open=false

func get_text(length: int=4) -> String:
	if not is_open or cursor>=lines.size(): close(); return END_TEXT
	if length<1: return END_TEXT
	var result=""
	for index in length:
		result+=lines[cursor]; cursor+=1
		if cursor>=lines.size() or _label(lines[cursor]): result+="[END]"; close(); break
	return result if not result.is_empty() else END_TEXT

func _seek(label: String) -> void:
	cursor=0
	if label.is_empty(): return
	for index in lines.size():
		if lines[index].strip_edges()=="["+label+"]": cursor=index+1; return
	# Original loop stops on the final line when the requested label is absent.
	cursor=maxi(0,lines.size()-1)

func _label(line: String) -> bool:
	var value=line.strip_edges(); return value.begins_with("[") and value.ends_with("]")
