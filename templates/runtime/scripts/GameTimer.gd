extends RefCounted
const P = preload("res://runtime/scripts/PictureState.gd")
signal expired
var remaining := 0.0
var running := false
var working := false
var visible := false
func start(seconds: Variant, show: bool = true) -> Dictionary:
	if not P.numeric(seconds, 0, 359999): return P.fail("倒计时必须为0–359999秒。")
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
	if not running or not is_finite(delta) or delta <= 0: return
	remaining = maxf(0, remaining - delta)
	if remaining == 0:
		running = false
		expired.emit()
func text() -> String:
	var seconds := int(ceil(remaining))
	return "%02d:%02d" % [seconds / 60, seconds % 60]
func snapshot() -> Dictionary: return {"remaining": remaining, "running": running, "visible": visible, "working": working}
static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() not in [3, 4] or not P.numeric(value.get("remaining"), 0, 359999) or not value.get("running") is bool or not value.get("visible") is bool or (value.running and value.remaining == 0): return P.fail("倒计时存档无效。")
	if not value.get("working", value.running or value.visible) is bool or (value.running and not value.get("working", true)): return P.fail("计时器工作状态无效。")
	var instance: RefCounted = load("res://runtime/scripts/GameTimer.gd").new()
	instance.remaining = value.remaining
	instance.running = value.running
	instance.visible = value.visible
	instance.working = value.get("working", value.running or value.visible)
	return {"ok": true, "value": instance}
