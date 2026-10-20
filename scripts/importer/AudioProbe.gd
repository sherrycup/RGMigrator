## 职责：在独立进程中探测原生音频解码结果，隔离损坏素材对迁移主进程的影响。
##
## 调用方式：
##   实例接口：先用 preload("res://scripts/importer/AudioProbe.gd").new(...) 构造，再调用下列方法。
##   节点脚本需要由所属场景管理；构造参数见 _init，场景树回调由 Godot 调用。
##
## 调用接口：
##   func _init() -> void
##     用途：构造本实例并记录初始化依赖。
##     参数：无。
##     返回：构造函数本身不返回值；通过 .new(...) 获得该脚本的实例。
##
## 接口说明结束。

extends SceneTree


## Isolated native decoder: a malformed source must never crash the migrator process.
func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		quit(2)
		return
	var bytes := FileAccess.get_file_as_bytes(arguments[0])
	print("RGM_AUDIO_DECODE_BEGIN")
	var stream: AudioStream
	if arguments[0].get_extension().to_lower() == "wav":
		stream = AudioStreamWAV.load_from_buffer(bytes)
	else:
		stream = AudioStreamMP3.load_from_buffer(bytes)
	var valid := stream != null and stream.get_length() > 0
	print("RGM_AUDIO_DECODE_END")
	var file := FileAccess.open(arguments[1], FileAccess.WRITE)
	if file != null:
		file.store_string(
			JSON.stringify(
				{
					"ok": valid,
					"sha256": FileAccess.get_sha256(arguments[0]),
					"length": stream.get_length() if valid else 0.0
				}
			)
		)
		file.close()
	quit(0 if valid else 1)
