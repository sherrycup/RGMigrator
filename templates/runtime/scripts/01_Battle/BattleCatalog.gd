## 职责：读取和校验闪翼战斗数据库、技能定义及相关配置，提供战斗对象目录。
##
## 调用方式：
##   静态接口：preload("res://runtime/scripts/01_Battle/BattleCatalog.gd").方法名(...)。
##
## 调用接口：
##   static func install_catalog(registry: RefCounted, catalog: Dictionary) -> Dictionary
##     参数 registry（RefCounted；必填）：类、方法、技能或绑定的登记表。
##     参数 catalog（Dictionary；必填）：对象或技能的只读目录服务。
##     返回：结果字典；ok 表示成功与否，失败原因及其他数据按实际返回分支提供。
##
## 公开常量：SOURCE_PATH。
## 接口说明结束。

extends RefCounted
## The importer writes the original 0073 definitions to an editable GDScript
## catalog. Its INPUT_SHA identifies the untouched source JSON, not edited values.
const SOURCE_PATH = "res://runtime/generated/skill_catalog.gd"


static func install_catalog(registry: RefCounted, catalog: Dictionary) -> Dictionary:
	var source_skills: Dictionary = catalog
	if FileAccess.file_exists(SOURCE_PATH):
		var script: Variant = load(SOURCE_PATH)
		if not script is GDScript or not script.can_instantiate():
			return {"ok": false, "message": "闪翼 GDScript 技能注册源码无法加载：" + SOURCE_PATH}
		var constants: Dictionary = script.get_script_constant_map()
		# Normalize JSON numeric representation just like the migration importer.
		var canonical: Variant = JSON.parse_string(JSON.stringify(catalog))
		var input_sha = JSON.stringify(canonical).sha256_text()
		if constants.get("INPUT_SHA") == input_sha:
			if not script.has_method("source_skills"):
				return {"ok": false, "message": "闪翼技能源码缺少 source_skills()。"}
			var edited: Variant = script.source_skills()
			if not edited is Dictionary:
				return {"ok": false, "message": "闪翼 source_skills() 必须返回 Dictionary。"}
			source_skills = edited
	registry.configure(source_skills)
	return {"ok": true}
