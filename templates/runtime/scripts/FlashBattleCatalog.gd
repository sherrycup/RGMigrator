extends RefCounted
## The importer writes the original 0073 definitions to an editable GDScript
## catalog. Its INPUT_SHA identifies the untouched source JSON, not edited values.
const SOURCE_PATH="res://runtime/generated/flash_skill_catalog.gd"

static func install_catalog(registry: RefCounted,catalog: Dictionary) -> Dictionary:
	var source_skills: Dictionary=catalog
	if FileAccess.file_exists(SOURCE_PATH):
		var script: Variant=load(SOURCE_PATH)
		if not script is GDScript or not script.can_instantiate(): return {"ok":false,"message":"闪翼 GDScript 技能注册源码无法加载："+SOURCE_PATH}
		var constants: Dictionary=script.get_script_constant_map()
		# Normalize JSON numeric representation just like the migration importer.
		var canonical: Variant=JSON.parse_string(JSON.stringify(catalog))
		var input_sha=JSON.stringify(canonical).sha256_text()
		if constants.get("INPUT_SHA")==input_sha:
			if not script.has_method("source_skills"): return {"ok":false,"message":"闪翼技能源码缺少 source_skills()。"}
			var edited: Variant=script.source_skills()
			if not edited is Dictionary: return {"ok":false,"message":"闪翼 source_skills() 必须返回 Dictionary。"}
			source_skills=edited
	registry.configure(source_skills)
	return {"ok":true}
