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
	if kind=="script_retry": clear(); return
	if kind != "time": return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0000001: clear()

func accepts(value: String, expected_token: int) -> bool:
	return kind == value and (expected_token < 0 or token == expected_token)
