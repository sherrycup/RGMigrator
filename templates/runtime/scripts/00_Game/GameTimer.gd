## 职责：管理游戏计时器的启动、停止、帧推进和剩余时间查询。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/00_Game/GameTimer.gd").方法名(...)。
##   实例接口：先用 preload("res://runtime/scripts/00_Game/GameTimer.gd").new(...) 构造，再调用下列方法。
##
## 调用接口：
##   func start(seconds: Variant, show: bool = true) -> Dictionary
##     参数 seconds（Variant；必填）：以秒计的时长。
##     参数 show（bool；默认值 true）：是否显示提示或操作结果。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
##   func stop() -> void
##     用途：停止当前播放、动作或服务。
##     参数：无。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func advance(delta: float) -> void
##     用途：推进当前动作、等待或演出的时间状态。
##     参数 delta（float；必填）：本次推进的时间差，单位为秒。
##     返回：无返回值；处理结果通过对象状态、界面或相应信号体现。
##
##   func text() -> String
##     参数：无。
##     返回：文本结果；空字符串是否代表成功或缺失，按本方法约定处理。
##
##   func snapshot() -> Dictionary
##     用途：取得状态快照或当前计算视图。
##     参数：无。
##     返回：字典结果；字段结构与本方法返回的数据一致。
##
##   static func decode(value: Variant) -> Dictionary
##     用途：解析编码数据并返回对应原值或结构。
##     参数 value（Variant；必填）：需要读取、校验或写入的值。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 对外信号：
##   expired()：由持有方发出，通知对应状态或操作结果。
##
## 接口说明结束。

extends RefCounted
const P = preload("res://runtime/scripts/00_Game/PictureState.gd")
signal expired
var remaining := 0.0
var running := false
var working := false
var visible := false


func start(seconds: Variant, show: bool = true) -> Dictionary:
	if not P.numeric(seconds, 0, 359999):
		return P.fail("倒计时必须为0–359999秒。")
	remaining = float(seconds)
	running = remaining > 0
	working = true
	visible = show
	return {"ok": true}


func stop() -> void:
	running = false
	working = false
	visible = false


func advance(delta: float) -> void:
	if not running or not is_finite(delta) or delta <= 0:
		return
	remaining = maxf(0, remaining - delta)
	if remaining == 0:
		running = false
		expired.emit()


func text() -> String:
	var seconds := int(ceil(remaining))
	return "%02d:%02d" % [seconds / 60, seconds % 60]


func snapshot() -> Dictionary:
	return {"remaining": remaining, "running": running, "visible": visible, "working": working}


static func decode(value: Variant) -> Dictionary:
	if (
		not value is Dictionary
		or value.size() not in [3, 4]
		or not P.numeric(value.get("remaining"), 0, 359999)
		or not value.get("running") is bool
		or not value.get("visible") is bool
		or (value.running and value.remaining == 0)
	):
		return P.fail("倒计时存档无效。")
	if (
		not value.get("working", value.running or value.visible) is bool
		or (value.running and not value.get("working", true))
	):
		return P.fail("计时器工作状态无效。")
	var instance: RefCounted = load("res://runtime/scripts/00_Game/GameTimer.gd").new()
	instance.remaining = value.remaining
	instance.running = value.running
	instance.visible = value.visible
	instance.working = value.get("working", value.running or value.visible)
	return {"ok": true, "value": instance}
