## 职责：描述并推进事件等待条件，包括帧、人物路线和界面完成状态。
##
## 调用方式：
##   实例接口：先用 preload("res://runtime/scripts/02_Event/EventWait.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func begin(value: String, seconds: float = 0.0) -> void
##     参数 value（String；必填）：需要读取、校验或写入的值。
##     参数 seconds（float；默认值 0.0）：以秒计的时长。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func clear() -> void
##     用途：清空当前内容或状态。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func advance(delta: float) -> void
##     用途：推进当前动作、等待或演出的时间状态。
##     参数 delta（float；必填）：本次推进的时间差，单位为秒。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func accepts(value: String, expected_token: int) -> bool
##     参数 value（String；必填）：需要读取、校验或写入的值。
##     参数 expected_token（int；必填）：用于确认请求仍有效的期望标识。
##     返回：布尔结果；true/false 的条件以本方法的判断逻辑为准。
##
## 接口说明结束。

extends RefCounted
## Tokens change at every wait and cancellation, never depend on display FPS.
var kind := ""
var remaining := 0.0
var token := 0


func begin(value: String, seconds: float = 0.0) -> void:
	token += 1
	kind = value
	remaining = seconds


func clear() -> void:
	token += 1
	kind = ""
	remaining = 0.0


func advance(delta: float) -> void:
	if kind == "script_retry":
		clear()
		return
	if kind != "time":
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0000001:
		clear()


func accepts(value: String, expected_token: int) -> bool:
	return kind == value and (expected_token < 0 or token == expected_token)
