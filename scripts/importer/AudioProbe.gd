extends SceneTree
## Isolated native decoder: a malformed source must never crash the migrator process.
func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		quit(2)
		return
	var bytes := FileAccess.get_file_as_bytes(arguments[0])
	var stream: AudioStream
	if arguments[0].get_extension().to_lower() == "wav":
		stream = AudioStreamWAV.load_from_buffer(bytes)
	else:
		stream = AudioStreamMP3.load_from_buffer(bytes)
	var valid := stream != null and stream.get_length() > 0
	var file := FileAccess.open(arguments[1], FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"ok": valid}))
		file.close()
	quit(0 if valid else 1)
