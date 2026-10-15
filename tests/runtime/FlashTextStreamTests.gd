extends SceneTree
var failures: Array[String]=[]
var checks=0
func _init() -> void: call_deferred("run")
func run() -> void:
	var file=FileAccess.open("res://legacy/extras/v046-textstream-test.txt",FileAccess.WRITE); file.store_string("[a]\n第一行\n第二行\n[b]\n第三行\n第四行"); file.close()
	var stream=load("res://runtime/scripts/FlashTextStream.gd").new()
	expect(stream.open("v046-textstream-test","a"),"source relative UTF-8 file and label open")
	expect(stream.get_text(1)=="第一行\n" and stream.is_open,"source line pointer preserves line ending and limit")
	expect(stream.get_text(4)=="第二行\n[END]" and not stream.is_open,"next label closes current source block")
	expect(stream.get_text()=="\\~\\/[END]","closed source returns close marker exactly")
	expect(stream.open("v046-textstream-test","b") and stream.get_text(4)=="第三行\n第四行[END]","reopening starts requested block and retains final line without newline")
	expect(not stream.open("../outside") and not stream.failure.is_empty() and not stream.is_open,"textstream rejects path traversal instead of reading external paths")
	expect(not stream.open("missing-source-file") and stream.file_name.is_empty(),"missing original auxiliary file remains source false")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://legacy/extras/v046-textstream-test.txt"))
	for message in failures: printerr("FAIL: ",message)
	print("FLASH TEXT STREAM: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks"); quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
