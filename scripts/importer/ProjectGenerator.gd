class_name ProjectGenerator
extends RefCounted

const RGMigratorVersion = preload("res://scripts/Version.gd")
const EXTRA_README := """
## 人物移动与地图接口（ver0.18）

方向键平滑四方向行走，采用原 Characters 的四方向四帧；速度 1–6，像素/秒为 10×2^速度，默认 4。RuntimeState.player() 返回当前游戏的真实玩家节点（标题无玩家时为 null），提供 move_straight(2/4/6/8)、turn(direction)、move_to(x,y)、jump(dx,dy)、moving()、jumping()、is_idle()、motion_snapshot()。逻辑格坐标在到达后提交，real_x/real_y 用地图像素，不是旧 RGSS 的 128 单位；完成普通行走加一步，撞墙、原地转向和跳跃不计步。穿透仍受地图边界约束，跳跃可跨障碍但必须有合法落点；无自动寻路、斜向输入或战斗伤害。

RuntimeState.configure_player({move_speed, through, direction_fix, walk_anime, step_anime, transparent, opacity, blend_type, idle_pattern}) 接受部分更新，先校验后生效；玩家节点也提供前八项同名属性。角色运行图/色相继续来自队伍首位 Actor，纹理共享、显示材料独立。地图实例提供 valid、tile_id(x,y,layer)、terrain_tag、is_bush、is_counter、event_ids_at、can_move；支持起点/落点双向通行、人物占位、柜台隔格确认和草丛下半身半透明。图块按数据库优先级与人物脚点原生排序，地面和前景保留绘制数据；自动图块按时间更新，菜单暂停。

Esc/X 在行走途中会等到本格完成再开菜单，不截断人物在半格；对话/诊断期间不能打开。玩家选项接入 schema 1 存档，旧新格式缺字段使用默认选项；不保存半格移动、跳跃进度或事件人物的原生位移，直接存档也拒绝正在行走/跳跃。不读取 RM 旧存档，不执行事件页自主移动、强制路线、随机/接近移动或自定义魔塔钩子，事件系统仍安排在 ver0.2–0.3，不新增事件指令。

测试准备开启后：Esc → F6 → 人物与地图。独立验收区直接使用正式移动/地图组件，包含草丛、地形7、单向红地块、柜台人物、触碰点和黄色遮挡图块；方向键行走、Z/Enter/Space 交互、Q 跳跃，按钮支持鼠标；Tab/F5 选择/执行按钮。速度、穿透、方向固定、踏步、行走动画可改；“应用到玩家”只修改真实玩家选项，不改其坐标/步数/背包/开关/变量。“恢复默认”只改预览，需应用才影响真实玩家。验收区报告触发结果，不运行它的事件命令，不替换原地图或数据库；关闭测试模式隐藏。

## 分类素材接口

const Cache = preload("res://runtime/scripts/RmxpCache.gd")。Cache.picture(name)、icon(name)、title(name)、windowskin(name)、character(name)、animation(name)、tileset(name)、autotile(name)、panorama(name)、fog(name)、battler(name)、gameover(name)、transition(name) 各自只查对应 Graphics 分类；同名文件不跨库匹配，缺失返回 null，不读取 RTP，越界路径拒绝。素材共享纹理，位置/色相/色调等显示参数由各显示实例管理，不修改缓存纹理。

为未来编辑器预留 Cache.categories()、list_names(category)、list_assets(category)、resolve(category, name)、exists(category, name)。分类枚举读取 data/asset_index.json，不加载图片，不注入工具测试素材，不混合其他目录；列表用原文件名（含扩展名）去除索引别名，每条包含 category/name/source_key/path，保留中文、子目录及扩展名修正后的映射。F6 图片选择器已使用 Pictures 分类。Cache.clear() 释放缓存引用，不销毁显示节点持有的纹理；编辑文件后仍需 Godot 资源重新导入，clear 不执行磁盘刷新。

这是原生 GDScript 分类接口，不是 Ruby 执行层或已实现的编辑器。当前运行时已提供雾/全景；战斗背景/Gameover等加载入口不表示对应场景行为已实现。

## 图片与屏幕接口

RuntimeState.show_picture(number, name, pose={})、move_picture(number, pose, seconds=0)、rotate_picture(number, degrees_per_second)、tint_picture(number, tone, seconds=0)、erase_picture(number)。地图图片编号 1–50，各自独立，编号越大层级越高；同号替换重置该图，缺失素材则保持原图并诊断，不补取 RTP。name 来自 Graphics/Pictures，pose 字段为 origin（0 左上/1 中心）、x/y（屏幕坐标）、zoom_x/zoom_y（百分比）、opacity（0–255）、blend_type（0 正常/1 加算/2 减算）。正旋转为逆时针；tone=[RGB −255..255, gray 0..255]。所有时长为秒，不接收旧帧数。

RuntimeState.screen 提供 picture(number)、picture_ids()、snapshot()、start_tone_change(tone, seconds)、start_flash([RGBA 0..255], seconds)、start_shake(power_px, speed_hz, seconds)。地图色调/震动只影响地图、角色和地图动画，图片不跟随摄像机；闪光覆盖地图及图片，对话和菜单保持清晰。时间驱动过渡，震动采用波形及结束包络，不照搬 RGSS 40 FPS 主循环。普通菜单/商店暂停效果，返回地图继续；传送保留状态，标题销毁显示层，新游戏清空。

测试准备开启时：Esc → F6 → 图片与屏幕。可以直接选择源图片并测试双图、变换、色调与屏幕效果；另有本工具绘制的测试色块，非 RTP。该页在暂停地图的同时推进效果预览，离开恢复普通菜单暂停；全部重置不改地图和角色。编号/素材下拉框用鼠标，操作按钮支持方向键与确认。显示状态、剩余过渡及旋转接入 schema 1 新存档；旧新格式缺少 screen 时默认空图片/中性效果，工程、数据与测试定义校验仍生效。

这是标准底层替代，不是 Ruby 执行或事件指令扩展。本版不接通 231–234、223–225，保留原有擦除图片 235；旧工程事件仍按支持清单诊断。当前运行时提供全景/雾/天气、独立地图区域与跟随中心、滚图、画面过渡、计时器和统一音频；参见 MAP_PRESENTATION.md。ver0.2归档已验收基础，事件命令接入仍安排在后续ver0.2–0.3阶段。天气目前位于RuntimeState.map_effects，接入事件前须归入Game_Screen对应层统一管理，不重复保存天气状态。

## 商店与 State 接口

标准商店支持物品/武器/防具的购买、出售、数量确认与装备信息。原事件 302/605 可打开商店，离开后继续事件；测试模式主菜单底部“测试工具 · F6”统一进入角色成长、测试商店与状态接口。购买使用数据库 price，出售为半价取整，零价不能出售；库存上限 99，交易金币上限 9999999，失败/取消不部分修改，不出售身上装备。数量 ←→ 调整 1、↑↓ 调整 10，确认交易、Esc 取消。列表向上先移动光标，越过可见上缘才滚动。

State 仅登记：actor.add_state(id)、remove_state(id)、has_state(id)、get_state_ids(include_equipment=true)、clear_states()；RuntimeState 提供 change_state、has_state、state_ids_for、clear_states 入口。普通来源与装备自动状态分开，存档保存普通 ID，装备来源重算。28 字段保留、已有倍率显示保留；不执行死亡、中毒、概率/回合解除、连锁状态或循环状态动画，不新增状态事件指令。

测试模式新游戏另给 2000 金币及两个中性状态（一个初始附加），在统一测试工具中直接增删查询。data/test_setup.json 的 initial_gold、shop_goods、initial_states、toggle_state_id 可编辑，读档不重复发放；关闭 enabled 隐藏工具。旧测试定义发生变化时旧测试存档可能拒绝读取，不自动覆盖原件。

## 角色数据与成长接口

RuntimeState.actor(id) 是唯一角色对象。九项 maxhp/maxsp/str/dex/agi/int/atk/pdef/mdef 支持 get_parameter、set_parameter（精确最终值）、get_parameter_plus、set_parameter_plus、add_parameter_plus（永久增量）、parameter_sources（独立来源快照）。base_str 等包含数据库与装备；str_plus 等仅为角色永久修正，不保存装备修正。最终值再应用已有状态倍率与上下限。HP 最小 1、SP 最小 0，上限均 9999；力量/灵巧/速度/魔力最小 1，攻击/防御最小 0，上限均 999。actor.str += 1、actor.maxhp += 1、actor.exp += 1 接入原生接口，不表示可执行原 Ruby。atk/pdef/mdef 可写修正是原生扩展；倍率取整使精确目标不可达时拒绝，不部分修改。

set_experience/add_experience、set_level/add_level 更新等级与经验，跨级学职业特技，降级不遗忘，升级不回满。set_vital/add_vital、recover_vitals 处理 HP/SP，不执行状态效果、不清除状态。RuntimeState 对应 set/change_actor_parameter、set_actor_parameter_plus、set/change_actor_experience、set/change_actor_level、set/change_actor_vital、recover_actor_vitals、rename_actor、change_actor_class、set_actor_graphic。换职业保留经验/等级/特技，原子收回不兼容装备（固定槽位不阻止职业解除）；背包收不下则整次拒绝。测试装备仍遵守现有测试职业豁免。角色图用四方向四帧素材与色相，共用菜单和地图缓存。

在测试工具“角色数据与成长”选择角色/属性，修改永久修正、经验、等级、HP/SP；“姓名/职业/角色图”打开身份表单。键盘方向选择按钮、确认执行，Q/E 切属性；文本框编辑时 X/空格不会误返回，Esc 关闭表单。这些是运行时测试，不是数据库/地图编辑器。改动接入 schema 1 存档；旧新格式缺字段用零修正及数据库图像，仍需数据指纹/测试定义一致；新游戏或初始化加入重置。数据库只读，不转换自定义成长公式，不新增地图事件指令或战斗。
"""

var warnings: Array[String] = []


func generate(output_root: String, project_title: String, ini: Dictionary, progress: Callable = Callable(), source_id: String = "") -> Dictionary:
	warnings.clear()
	if progress.is_valid():
		progress.call("生成 Godot 运行时模板")
	var template_root := ProjectSettings.globalize_path("res://templates/runtime")
	_copy_tree(template_root.path_join("scripts"), output_root.path_join("runtime/scripts"))
	_copy_tree(template_root.path_join("scenes"), output_root.path_join("scenes"))
	_copy_file(template_root.path_join("MAP_PRESENTATION.md"), output_root.path_join("MAP_PRESENTATION.md"))
	var width := 640
	var height := 480
	var window: Dictionary = ini.get("Window", {})
	if int(window.get("width", 0)) > 0:
		width = int(window["width"])
	if int(window.get("height", 0)) > 0:
		height = int(window["height"])
	_write_project_file(output_root.path_join("project.godot"), project_title, width, height, (source_id if not source_id.is_empty() else project_title).replace("\\", "/").to_lower().sha256_text())
	var version_file := FileAccess.open(output_root.path_join("runtime/scripts/RuntimeVersion.gd"), FileAccess.WRITE)
	if version_file == null:
		warnings.append("无法写入运行时版本。")
	else:
		version_file.store_string("extends RefCounted\nconst VERSION := \"%s\"\n" % RGMigratorVersion.VERSION)
		version_file.close()
	_write_readme(output_root.path_join("README.md"), project_title)
	return {"warnings": warnings, "width": width, "height": height}


func _copy_tree(source: String, destination: String) -> void:
	if not DirAccess.dir_exists_absolute(source):
		warnings.append("运行时模板目录不存在：%s" % source)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	var dir := DirAccess.open(source)
	if dir == null:
		warnings.append("无法读取运行时模板目录：%s" % source)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not entry.begins_with(".") and not entry.ends_with(".uid"):
			var from := source.path_join(entry)
			var to := destination.path_join(entry)
			if dir.current_is_dir():
				_copy_tree(from, to)
			else:
				_copy_file(from, to)
		entry = dir.get_next()
	dir.list_dir_end()


func _copy_file(source_path: String, destination_path: String) -> void:
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		warnings.append("无法读取模板文件：%s" % source_path)
		return
	DirAccess.make_dir_recursive_absolute(destination_path.get_base_dir())
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		source.close()
		warnings.append("无法写入模板文件：%s" % destination_path)
		return
	destination.store_buffer(source.get_buffer(source.get_length()))
	destination.close()
	source.close()


func _write_project_file(path: String, title: String, width: int, height: int, project_id: String) -> void:
	var config := ConfigFile.new()
	config.set_value("application", "config/name", title)
	config.set_value("application", "run/main_scene", "res://scenes/Title.tscn")
	config.set_value("application", "config/features", PackedStringArray(["4.5", "GL Compatibility"]))
	config.set_value("autoload", "RuntimeState", "*res://runtime/scripts/RuntimeState.gd")
	config.set_value("rgmigrator", "project_id", project_id)
	# Empty arrays mean the complete logical screen and its center. Never parse Ruby UI code.
	config.set_value("rgmigrator", "map_view_rect", [])
	config.set_value("rgmigrator", "map_follow_center", [])
	for key in ["viewport_width", "window_width_override"]:
		config.set_value("display", "window/size/" + key, width)
	for key in ["viewport_height", "window_height_override"]:
		config.set_value("display", "window/size/" + key, height)
	config.set_value("display", "window/stretch/mode", "canvas_items")
	config.set_value("display", "window/stretch/aspect", "keep")
	config.set_value("display", "window/stretch/scale_mode", "integer")
	config.set_value("rendering", "renderer/rendering_method", "gl_compatibility")
	# Import-time safety only; does not serialize game rendering or runtime updates.
	config.set_value("editor", "import/use_multiple_threads", false)
	config.set_value("rendering", "textures/canvas_textures/default_texture_filter", 0)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		warnings.append("无法写入 project.godot：%s" % path)
		return
	file.store_string("; Generated by %s\nconfig_version=5\n" % RGMigratorVersion.DISPLAY_NAME + config.encode_to_text())
	file.close()


func _write_readme(path: String, title: String) -> void:
	var content := "# %s\n\n本工程由 %s 生成。\n\n- 启动后使用 Godot 原生标题界面进入新游戏。\n- 地图空闲时按 Esc/X 打开标准菜单，方向键选择，Enter/Space/Z 确认，Esc/X 返回；支持背包、基础恢复物品、装备更换与预览、角色状态及结束游戏。\n- 物品限菜单可用、确定性、对存活队友的单体/全体 HP/SP 恢复。公共事件、复活、状态、永久属性、随机效果等暂不执行，失败不消耗。技能列表只读，不执行效果或消耗。菜单提供四槽位存档，标题继续游戏可恢复进度；禁止存档状态会禁用入口。\n- 测试准备由 `data/test_setup.json` 控制：`enabled` 为 true 时，新游戏自动准备测试血瓶、魔法药、全队血瓶和装备，HP/SP 默认一半。修改 stock 数量或恢复比例后重新开始游戏即可；设为 false 恢复原始开局。测试记录独立于原数据库，每次新游戏重置，不叠加。\n- 测试装备可供有效职业使用，但不绕过固定槽位；原装备遵守数据库职业限制。\n- 角色属性采用标准数据库规则，力量/灵巧/速度/魔力/攻击力/物理防御/魔法防御使用标准标签，不读取 Ruby 自定义属性与魔塔公式。测试物品不是源工程自定义效果的迁移结果。\n- 特技支持学习/遗忘/查询，事件 318、角色已学特技条件分支 111 与显示动画 207 已接通。独立动画播放器不计算伤害、不扣 SP；缺失动画/素材会诊断，不补取 RTP。\n- 测试准备同时授予三个测试特技。进入特技列表可点击预览动画、学习/遗忘测试特技；Esc 先关闭预览再返回。关闭测试模式后不显示这些测试按钮。另有原动画/并发入口，读取原 Animations 数据与素材，支持双位置和同一目标连续追加播放。\n- 新存档位于项目专属 user://rgmigrator_saves/ 子目录，使用格式版本、数据指纹和完整性校验；写入临时文件后替换，覆盖保留上一份备份。损坏文件或不兼容数据不会部分恢复；备份读取需确认。读档不重复发测试物资。数据库/地图或测试定义改变时可能拒绝旧进度。\n- 不读取 RM 旧存档，不保存正在执行的事件、动画、瞬时音效或当前 BGM/BGS 播放进度。装备槽统一为武器、盾、头部防具、身体防具、饰品。\n- 输出关闭编辑器并行导入；未通过隔离解码检查的 MP3 或含辅助元数据 PCM WAV 保留至 legacy/unsupported_assets，图像扩展名错误修正导出副本与索引。其他原始音频仍可能需人工处理。\n- 迁移后的标准数据位于 `data/`，非 RTP 素材位于 `assets/rmxp/`。\n- 原始 Ruby 脚本与自定义文件仅供人工迁移参考，位于 `legacy/`。\n- 不支持的事件命令会在游戏内显示诊断；详情见 `migration_report.md`。\n" % [title, RGMigratorVersion.DISPLAY_NAME]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		warnings.append("无法写入输出 README：%s" % path)
		return
	file.store_string(content + EXTRA_README)
	file.close()
