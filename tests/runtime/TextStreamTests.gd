## 职责：回归验证：验证逐字文本流、控制标记、暂停与速度。
##
## 调用方式：
##   在独立测试工程中由测试运行器执行；场景脚本通过 --script 启动，辅助场景由对应测试调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
##   func run() -> void
##     用途：执行当前迁移流程或回归场景。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func expect(value: bool,message: String) -> void
##     用途：记录一项断言及失败说明。
##     参数 value（bool；必填）：需要读取、校验或写入的值。
##     参数 message（String；必填）：提示或诊断文本。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
## 接口说明结束。

extends SceneTree
var failures: Array[String]=[]
var checks=0
func _init() -> void: call_deferred("run")
func run() -> void:
	var file=FileAccess.open("res://legacy/extras/v046-textstream-test.txt",FileAccess.WRITE); file.store_string("[a]\n第一行\n第二行\n[b]\n第三行\n第四行"); file.close()
	var stream=load("res://runtime/scripts/06_Message/TextStream.gd").new()
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
