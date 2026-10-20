## 职责：回归验证：验证脚本自定义数据的静态提取、覆盖记录及失败诊断。
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
const Converter=preload("res://scripts/importer/RmxpDataConverter.gd")
const Codec=preload("res://scripts/importer/RmxpTextCodec.gd")
const Generator=preload("res://scripts/importer/ProjectGenerator.gd")
const Importer=preload("res://scripts/importer/CustomDataImporter.gd")
var checks=0
var failures: Array[String]=[]

func _init() -> void: call_deferred("run")

func run() -> void:
	var workspace=ProjectSettings.globalize_path("res://").get_base_dir().trim_suffix("/").get_base_dir()
	var roots: Array=[]
	for source in ["魔塔样板7630·改","小蛋挞(读1号存档即可)"]:
		var root=ProjectSettings.globalize_path("res://.godot/custom_data_fixture_"+str(Time.get_ticks_usec()))
		DirAccess.make_dir_recursive_absolute(root)
		var codec=Codec.new(936); var converter=Converter.new(codec)
		var converted=converter.convert(workspace.path_join("rm_template/"+source),root)
		expect(converted.ok,"original RM data converts for custom data fixture")
		Generator.new().generate(root,source,{},Callable(),workspace.path_join("rm_template/"+source))
		var imported=Importer.new().generate(workspace.path_join("rm_template/"+source),root,converter.script_sources,converter.script_inventory.raw_maps,codec,converter.script_inventory.raw_common)
		expect(imported.ok,"source custom data writes without errors")
		var manifest=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/custom_data.json")))
		print(source," CUSTOM DATA: ",JSON.stringify(manifest.summary))
		if source.begins_with("魔塔"):
			expect(manifest.profile=="flash" and manifest.currencies.size()==7,"source KIN and five spar currencies detected")
			expect(manifest.constants.EXTERNAL_DATA_ENEMY=="Enemy.exdata","configured enemy filename preserved exactly")
			expect(manifest.constants.POTION_ITEM_ID.size()==4 and int(manifest.constants.POTION_ITEM_ID["1"])==32 and int(manifest.constants.POTION_ITEM_ID["4"])==35 and manifest.constants.GEM_ITEM_ID.size()==4 and int(manifest.constants.GEM_ITEM_ID["3"])==36,"sequential source index assignments populate potion and gem tables, not only their empty initial Hash")
			expect(int(manifest.system_defaults.map_range[0]._integer_range[0])==1 and int(manifest.system_defaults.map_range[0]._integer_range[1])==18 and not manifest.system_defaults.map_range[0].exclusive,"source floor bounds retain inclusive ranges")
			expect(manifest.actor_presets["2"]["0"].patk==5,"real Actor_Init preset data retained")
			var items=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/database/Items.json")))
			expect(items[1]._custom_data.external.settings.consumable==false and items[1].consumable==items[1]._custom_data.original_fields.consumable.value and items[1].occasion==3,"literal false is preserved and the source Ruby || getter retains the actual base field")
			expect(items[1].description.contains("第四行。"),"multiline custom description retained")
			expect(manifest.diagnostics.any(func(d: Dictionary) -> bool: return d.code=="external_missing" and d.message.contains("Enemy.exdata")),"missing configured file diagnosed rather than substituting Enemies.txt")
		else:
			expect(manifest.profile=="antinomy" and str(manifest.currencies[0].maximum).length()>19,"source arbitrary precision gold maximum retained")
			var enemies=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/database/Enemies.json")))
			var weapons=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("data/database/Weapons.json")))
			expect(enemies[997].maxhp==4000000000 and enemies[995].maxhp==1000000000000,"source large monster data is not truncated to int32")
			expect(enemies[802].maxsp==20000 and enemies[802].maxhp==50000000,"last source set(802) wins while independent maxsp is retained")
			expect(weapons[150].str_plus==10000000000 and weapons[150].dex_plus==10000000000,"source custom equipment fields retain large values")
			expect(weapons[227].name.begins_with("黑蚀披风:") and weapons[227]._custom_data.tags.size()>0,"custom name tags retain raw text and values")
			expect(manifest.globals.has("$友军列表"),"Chinese global data names retained")
		roots.append(root)
	var file=FileAccess.open("res://.godot/v044-fixture-paths.json",FileAccess.WRITE); file.store_string(JSON.stringify(roots)); file.close()
	for failure in failures: printerr("FAIL: ",failure)
	print("CUSTOM DATA IMPORTER: ","PASSED" if failures.is_empty() else "FAILED"," / ",checks," checks")
	quit(0 if failures.is_empty() else 1)

func expect(value: bool,message: String) -> void:
	checks+=1
	if not value: failures.append(message)
