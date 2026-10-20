## 职责：回归验证：验证原音频探测、解码隔离及迁移期转换与来源记录。
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
const Copier=preload("res://scripts/importer/RmxpAssetCopier.gd")
var checks=0
var failures: Array[String]=[]
func _init() -> void: call_deferred("run")
func run() -> void:
	var digest="a".repeat(64)
	var result={"ok":true,"sha256":digest,"length":2.0}
	var clean="RGM_AUDIO_DECODE_BEGIN\nRGM_AUDIO_DECODE_END\n"
	expect(Copier._clean_probe_result(result,"ERROR: Failed to read the root certificate store.\n"+clean,digest),"startup TLS error does not quarantine valid audio")
	expect(not Copier._clean_probe_result(result,clean.replace("RGM_AUDIO_DECODE_END","ERROR: invalid MPEG frame\nRGM_AUDIO_DECODE_END"),digest),"decoder errors still reject partial audio")
	expect(not Copier._clean_probe_result(result,clean.replace("RGM_AUDIO_DECODE_END","Unicode parsing error\nRGM_AUDIO_DECODE_END"),digest),"malformed decoder metadata is still rejected")
	expect(not Copier._clean_probe_result(result,"RGM_AUDIO_DECODE_BEGIN\n",digest),"incomplete/crashed decode cannot succeed")
	expect(not Copier._clean_probe_result(result,clean,"b".repeat(64)),"stale/wrong-input probe evidence cannot succeed")
	var folder=ProjectSettings.globalize_path("res://.godot/audio_import_%d" % Time.get_ticks_usec())
	var source=folder.path_join("source"); var destination=folder.path_join("output")
	DirAccess.make_dir_recursive_absolute(source.path_join("Audio/BGM"))
	var original=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("rm_template/魔塔样板7630·改/Audio/BGM")
	for name in DirAccess.get_files_at(original):
		expect(DirAccess.copy_absolute(original.path_join(name),source.path_join("Audio/BGM/"+name))==OK,"copy actual original BGM fixture "+name)
	var invalid=FileAccess.open(source.path_join("Audio/BGM/invalid.mp3"),FileAccess.WRITE); invalid.store_buffer(PackedByteArray([1,2,3,4])); invalid.close()
	var copier=Copier.new(); var copied=copier.copy(source,destination)
	expect(copied.errors.is_empty(),"targeted audio migration succeeds")
	var count=0
	for name in DirAccess.get_files_at(original):
		var key="Audio/BGM/"+name; var output=str(copied.asset_index.get(key,""))
		expect(not output.is_empty() and copied.asset_index.get(key.get_basename())==output,"original full name and extensionless reference indexed "+name)
		if output.is_empty(): continue
		var absolute=destination.path_join(output.trim_prefix("res://"))
		if name.get_extension()=="mp3":
			count+=1
			expect(FileAccess.get_sha256(absolute)==FileAccess.get_sha256(original.path_join(name)),"MP3 bytes preserved "+name)
		else:
			expect(output.ends_with(".wav") and FileAccess.get_file_as_bytes(absolute).slice(0,4).get_string_from_ascii()=="RIFF","MP2 becomes standard WAV")
			expect(FileAccess.get_sha256(destination.path_join("legacy/unsupported_assets/"+key))==FileAccess.get_sha256(original.path_join(name)),"original MP2 bytes preserved")
	expect(count==7,"all seven actual map MP3s imported")
	expect(not copied.asset_index.has("Audio/BGM/invalid") and FileAccess.file_exists(destination.path_join("legacy/unsupported_assets/Audio/BGM/invalid.mp3")),"invalid MP3 stays isolated and preserved")
	var conversions=JSON.parse_string(FileAccess.get_file_as_string(destination.path_join("data/asset_conversions.json")))
	expect(conversions.entries.size()==1 and conversions.entries[0].source.ends_with(".mp2"),"one actual MP2 conversion has explicit origin")
	if conversions.entries.size()==1:
		var entry=conversions.entries[0]
		expect(FileAccess.get_sha256(source.path_join(entry.source))==entry.source_sha256 and FileAccess.get_sha256(destination.path_join(entry.output_path))==entry.output_sha256,"conversion provenance hashes match actual files")
	for message in failures: printerr("FAIL: ",message)
	print("AUDIO IMPORT: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)
func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
