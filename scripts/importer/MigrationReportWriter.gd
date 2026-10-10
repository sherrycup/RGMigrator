class_name MigrationReportWriter
extends RefCounted

const RGMigratorVersion = preload("res://scripts/Version.gd")


func write(output_root: String, details: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	var json_path := output_root.path_join("migration_report.json")
	var markdown_path := output_root.path_join("migration_report.md")
	var json_file := FileAccess.open(json_path, FileAccess.WRITE)
	if json_file == null:
		warnings.append("无法写入迁移 JSON 报告：%s" % json_path)
	else:
		json_file.store_string(JSON.stringify(details, "\t", true) + "\n")
		json_file.close()
	var markdown_file := FileAccess.open(markdown_path, FileAccess.WRITE)
	if markdown_file == null:
		warnings.append("无法写入迁移 Markdown 报告：%s" % markdown_path)
		return warnings
	markdown_file.store_string(_markdown(details))
	markdown_file.close()
	return warnings


func _markdown(details: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# %s 迁移报告" % RGMigratorVersion.DISPLAY_NAME)
	lines.append("")
	lines.append("- 源工程：`%s`" % details.get("source_path", ""))
	lines.append("- 输出工程：`%s`" % details.get("output_path", ""))
	lines.append("- 项目标题：%s" % details.get("project_title", ""))
	lines.append("- 文本编码：%s" % details.get("encoding", ""))
	lines.append("- 迁移地图：%d" % int(details.get("maps", 0)))
	lines.append("- 迁移数据文件：%d" % int(details.get("data_files", 0)))
	lines.append("- 复制非 RTP 素材：%d" % int(details.get("assets", 0)))
	lines.append("- 保留 Ruby 脚本：%d" % int(details.get("scripts", 0)))
	lines.append("")
	lines.append("## 错误")
	var errors: Array = details.get("errors", [])
	if errors.is_empty():
		lines.append("无。")
	else:
		for error in errors:
			lines.append("- %s" % error)
	var warnings: Array = details.get("warnings", [])
	lines.append("")
	lines.append("## 警告")
	if warnings.is_empty():
		lines.append("无。")
	else:
		for warning in warnings:
			lines.append("- %s" % warning)
	var unsupported: Array = details.get("unsupported_commands", [])
	lines.append("")
	lines.append("## 不支持的事件命令")
	if unsupported.is_empty():
		lines.append("未在可解析的地图、公共事件、敌群事件或移动路线中发现。")
	else:
		lines.append("| 地图 | 事件 | 页 | 命令序号 | 指令 | 原因 |")
		lines.append("| --- | ---: | ---: | ---: | ---: | --- |")
		for item in unsupported:
			var reason: String = item.get("reason", "")
			if item.has("route_index"): reason = "路线第 %d 条（代码 %d）：%s" % [item.route_index, item.route_code, reason]
			lines.append("| %s | %s | %s | %s | %s | %s |" % [item.get("map", ""), item.get("event_id", ""), item.get("page", ""), item.get("command_index", ""), item.get("code", ""), reason])
	lines.append("")
	lines.append("## %s 标准功能与限制" % RGMigratorVersion.VERSION)
	lines.append("已提供 Godot 标准主菜单、队伍摘要、角色状态及返回标题/退出。地图空闲时按 Esc/X 打开，保留窗口皮肤与界面用语；属性标签统一为标准力量/灵巧/速度/魔力/攻击力/物理防御/魔法防御，不沿用 Ruby 自定义属性映射。皮肤缺失时使用简易样式并报告。")
	lines.append("生成工程内置%s地图、事件、数据库与公共事件编辑器。Godot的“魔塔编辑器”按F9打开数据库；引用显示名称＋编号并支持搜索，事件和路线使用中文摘要。角色成长、装备许可、图块标记和动画单元可用表格/集合制作，公共事件提供无/自动/并行及共享非脚本指令编辑。草稿通过显式保存写入data，保留原ID和Ruby注释数据。原生Troops只保留查看，扩展数据库文件仍迁移保留。" % RGMigratorVersion.VERSION)
	lines.append("这是标准功能替代，不是自定义脚本迁移。角色数值使用标准数据库、等级曲线和初始装备规则，不读取 Ruby 定义的额外属性、货币或魔塔公式。")
	lines.append("人物支持原生平滑四方向移动、四帧/色相、速度与方向固定/穿透/步行动画/踏步、合法落点跳跃。保留双向通行与人物占位，补齐地形/草丛/柜台查询和隔柜台确认；按数据库图块优先级和人物脚点排序，自动图块按时间更新，摄像机限制在地图范围。移动完成才提交格坐标与步数；行走中按菜单会等待本格完成，存档拒绝半格运动。参数接入 schema 1，旧原生存档缺字段用默认值；不读取 RM 旧存档。")
	lines.append("ver0.21 接通确认、玩家接触、事件接触、自动执行与独立并行，公共事件调用/自动/并行，以及等待106和暂时删除116。等待按秒推进，20个原生等待单位为1秒。开关/变量/独立开关刷新依赖事件页；并行界面请求排队，旧回调不能恢复新执行。自主移动/强制路线已在ver0.23接入。ver0.27已持久化执行现场、事件人物和本图暂时删除状态。默认回合制战斗不在迁移范围；魔塔公共事件与自定义结算后续单独接入。")
	lines.append("支持背包查看、菜单可用的确定性单体/全体存活队友 HP/SP 恢复、装备更换/卸下及数值预览。职业资格、槽位类型、固定槽位和数量会先校验；失败不消费、不交换。公共事件物品已接通使用预约；复活、状态、永久属性、随机/命中/防御/属性修正的队友物品仍不会部分执行。")
	lines.append("特技列表接通菜单公共事件使用和SP消耗，接通增减特技 318、角色已学特技条件分支 111（角色/特技子类型）、显示动画 207。提供学习/遗忘/查询和 ID 列表接口；技能标准字段保留；公共事件使用先校验后扣SP，未支持的队友结算不部分执行，Ruby不执行。")
	lines.append("独立动画播放器读取原动画 ID 与单元帧数据，支持图块变换、色相/透明度/混合、目标/画面定位、音效、条件时序、闪光与暂时隐藏；按标准每秒 20 个动画帧计时，不绑定渲染 FPS。0 表示无动画，坏引用/缺素材会诊断，不补取 RTP。")
	lines.append("新增四槽位新工程存档与标题继续游戏：保存地图/位置/朝向、角色/装备/特技/状态 ID、队伍、背包、金币、开关变量独立开关、步数、游戏时间、禁用标志及测试模式。读档先整体校验再恢复，不走新游戏初始化、不重复发测试物资。存档位于项目专属 user://rgmigrator_saves/ 子目录，包含格式版本、工程/数据指纹和 SHA-256 完整性校验；临时文件写入后替换，覆盖保留备份，主文件不可用时可确认读取备份。")
	lines.append("不读取 RM 旧存档、不恢复 Ruby 自定义数据；运行中的事件已持久化，动画和ME/SE瞬时音效不保存；BGM/BGS位置、记忆与淡出已保存。普通菜单存档遵守禁止存档；352可显式打开并保存，读档从后续指令继续。玩家半格、传送及瞬时过渡仍拒绝保存。Ruby不执行、RTP不补取、回合制战斗排除；其他未支持指令仍会诊断并中断。装备槽名称统一为武器、盾、头部防具、身体防具、饰品。")
	lines.append("标准商店支持物品/武器/防具购买与出售、数量确认、数据库价格（出售半价取整）、金币/99 件库存限制和装备属性比较。接通 302 商店处理及 605 商品续行；退出后继续原事件，保留地图实例。交易先校验再修改金币/库存，失败或取消不部分交易，不出售角色身上装备，不恢复魔塔自定义属性商店。")
	lines.append("State支持actor.add_state/remove_state/has_state/get_state_ids/clear_states与RuntimeState对应入口。普通来源和装备自动来源分开，zero_hp控制HP0/解除最后死亡状态恢复HP1，plus/minus关联与互斥先校验再提交；循环超过预算拒绝。保留倍率与存档，不执行中毒、概率/回合解除、状态动画或回合制战斗。")
	lines.append("角色数据接口新增九项永久修正、最终属性赋值、HP/SP、经验/等级、姓名、职业及角色图/色相。base 属性包含数据库与装备；角色永久 plus 独立保存，最终值应用已有状态倍率及上下限。经验跨级按标准职业学习表学特技，降级不遗忘，升级不治疗；换职业原子收回不兼容装备。直接最终赋值不能精确达到时拒绝，不猜测数值。atk/pdef/mdef 的可写永久修正是原生扩展，不执行 Ruby 或自定义公式。")
	lines.append("永久修正及图像信息接入新工程存档 schema 1；旧新格式存档缺少字段时使用零修正/数据库图像，仍需工程、数据和测试定义一致。不迁移 RM 旧存档。商店、背包及特技列表保留滚动视口，向上先移动光标，仅越过上缘时滚动。")
	lines.append("原生图片/屏幕状态已补齐：地图编号 1–50 独立显示/替换/擦除，屏幕坐标、原点、缩放、透明度、正常/加算/减算混合、旋转和色调；地图色调/震动、屏幕闪光。时长用秒，旋转用度/秒、震动用像素/Hz；按时间推进，不绑定 RGSS 40 FPS。图片不跟随摄像机、不受地图色调/震动影响；闪光覆盖游戏而不覆盖对话或菜单。普通菜单暂停，仅图片测试页继续效果预览；传送保留，新游戏清空。状态及过渡进度接入 schema 1 存档，缺字段默认空图片/中性效果。")
	lines.append("当前运行时提供图块集全景/雾、原生雨/暴风雨/雪、独立地图显示矩形及跟随中心、双轴边界跟随/手动滚图、淡入淡出/真实截图灰度过渡、倒计时和统一音频播放/音调/淡出/记忆恢复。F6提供独立大地图和原素材测试；地图参数/表现/计时器进入schema1存档，瞬时截图和ME/SE不保存，BGM/BGS进度已持久化。生成工程MAP_PRESENTATION.md说明配置与接口。")
	lines.append("ver0.2归档已验收标准运行时基础；ver0.21/0.22已接入事件执行和消息/状态逻辑。后续事件开发契约位于迁移器仓库AGENTS.md；天气唯一归RuntimeState.screen，地图表现仅显示，不复制或重复推进天气状态。")
	lines.append("ver0.24已接图片/屏幕/天气/过渡；ver0.25已接皮肤、滚图、全景/雾与音频。缺失素材不补取RTP，不自动执行Ruby的中心参数或UI代码。其他事件命令按ver0.2系列后续计划接入。")
	lines.append("生成工程关闭编辑器并行导入；MP3 与含辅助元数据的 PCM WAV 在独立 Godot 进程内检查，未通过者原样保留到 legacy/unsupported_assets；JPEG/PNG 扩展名错误只修正导出副本和素材索引。保留不代表素材已可播放，其他编码问题仍可能需要人工处理。")
	lines.append("")
	lines.append("## 测试准备")
	var testing: Dictionary = details.get("test_setup", {})
	lines.append("迁移时测试准备：%s。配置位于 `data/test_setup.json`，可直接修改，无需修改 RM 工程或重新迁移。" % ("开启" if testing.get("enabled", false) else "关闭"))
	lines.append("开启时每次新游戏重置测试血瓶、魔法药、全队血瓶与武器/四类防具，HP/SP 默认一半；标题、地图与背包标记测试模式。设 enabled 为 false 后新游戏不注入物资。测试定义是独立覆盖层，不修改源数据库，也不代表自定义脚本已迁移。固定装备槽仍禁止更换。")
	lines.append("另自动学习三个测试特技：两个共用动画、一个无动画。特技列表中的测试按钮可预览动画或通过指令 318 学习/遗忘指定测试特技；正式模式不显示这些按钮。")
	lines.append("测试模式另有原动画/并发入口：直接选择原 Animations 数据与素材，可在双位置播放或向同一目标追加多个实例；第二条播放动画 207 不改写第一实例的 ID 或进度。原素材缺失仍诊断，不补取 RTP。")
	lines.append("新游戏另准备 2000 测试金币、商品列表及两个中性测试状态（一个初始附加、一个可增删）；主菜单底部“测试工具 · F6”统一进入角色数据与成长、测试商店、状态接口，支持键盘及鼠标。正式模式隐藏。可修改 test_setup.json 的 initial_gold、shop_goods、initial_states、toggle_state_id，无需编辑原 RM 工程；读档不会重新发放。")
	lines.append("ver0.22接通消息104/按键105/计时器124，111/122支持全部非战斗条件/操作数，101–103支持控制字符、合并输入和分页。正式事件验收地图新增联合流程，以变量文本直观验收等待与循环；回合制战斗及Ruby排除。")
	lines.append("ver0.23接通自主移动、完整非脚本移动路线209/509、全地图强制路线等待210、位置202、玩家透明208，并补全201方向/淡化/等待及207目标生命周期。支持路线阻挡重试/跳过、重复、原路线恢复与全部0..44子指令；45脚本保留但不执行。事件人物/路线现场已在0.27持久化；本版不新增演示场景。")
	lines.append("ver0.27接通352与完整事件现场存档：当前地图所有事件保留位置/朝向及移动结束后的图形、透明度、速度、频度、动画/穿透/固定方向/置顶等属性；平滑运动、强制/原自主路线游标与等待、前台/两类并行的调用栈/循环/分支及UI队列一并恢复。存档页从后续指令继续，不重复奖励。菜单物品/技能校验后消耗一次、预约公共事件并返回地图；未知结算不部分执行。schema1缺字段兼容旧迁移器存档，不读RM旧存档。没有新增演示场景。")
	lines.append("ver0.26接通129/135、311–322及303/351/353/354。角色单个/全体事务、变量增减、死亡/状态关联、原生全回复顺序、六能力值和强制装备/职业规则已接入；满库存回收整次拒绝避免丢装备。303使用系统输入法与Unicode限长，Esc删除字符；351可显式越过玩家菜单禁止。302/303/351共用排队与请求身份，关闭仅恢复原事件；353/354先清理旧事件/并行/路线再切换实际Gameover/Title。322战斗图仅保存元数据。352与执行现场存档已在0.27接通。没有新增演示场景，文本增强暂缓。")
	lines.append("ver0.25接通131、203–206全景/雾（战斗背景排除）、241–251音频；原生速度/秒时间适配、双频道音频恢复原子预检、皮肤与BGM/BGS播放位置/记忆/淡出持久化。204含非战斗子类型，目标为75条主命令。")
	lines.append("ver0.24接通221–225、231–236，图片/屏幕参数原子校验，普通/蒙版过渡按真实完成等待和请求身份取消。天气唯一归ScreenState，换图保留/新游戏重置/菜单和过渡暂停，旧schema1地图天气校验迁入screen。图片/色调等时长参数/20秒，天气/40秒，旋转×20度/秒；震动按原生振幅/周期平滑处理。本版不新增演示场景，文本增强暂缓。")
	lines.append("F6 测试工具新增“图片与屏幕”：选择编号和源 Graphics/Pictures 素材，直接测试双图、变换、色调、闪光、震动和擦除；另有工具绘制色块，非 RTP。仅该测试页允许在暂停地图时推进预览，离开恢复正常暂停；无需回 RM 修改。")
	lines.append("F6 另有“人物与地图”独立验收区：直接使用正式地图/人物组件测试行走、草丛、地形、柜台、碰撞与跳跃；原地图保持暂停。可调速度/穿透/方向固定/踏步/步行动画，再按“应用到玩家”修改真实选项；不改原地图、数据库、真实坐标、步数或物资。原创验收素材不是 RTP，触发仅用于报告结果，不执行测试事件命令。")
	for stock in testing.get("stock", []):
		lines.append("- 测试库存 %s:%s × %s" % [stock.get("kind", ""), stock.get("id", ""), stock.get("quantity", 0)])
	return "\n".join(lines) + "\n"
