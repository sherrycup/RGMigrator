# 0.47 实施与源码入口

2026-10-14。仅匹配黎之闪翼（开发中）；特殊BOSS、原生回合战、RTP和RM旧存档继续排除。0.47接入下表职责；不将版本号或生成单元数当作原全部Ruby自动转译完成。整体验收尚未进行。

| 任务 | 实际入口 | 本轮行为 |
| --- | --- | --- |
| 47-01 配置与解锁 | FlashPreferences、FlashFileStore、CustomDataState | 项目隔离的配置文件，101全局变量、音量/奔跑/显示模式、音乐锁及成就数组；校验后原子替换、备份恢复。全局数据不随进度撤回。 |
| 47-02 完整存档与摘要 | SaveGraph、SaveCodec、ScriptRuntime、EventPersistence、FlashPresentationState、FlashObjectCatalog | 共享/循环数据、类型化键、int64，自定义实例字段、装备缓存身份、生成类/方法/alias来源；消息游标/选择输入、冻结/演出/消散和跟随。恢复后重新绑定界面请求、等待和显示对象，原消息历史不重复。摘要仍用FlashArchiveData同一状态。 |
| 47-03 自动记录与撤回 | FlashHistory、MapRuntime、Game、MenuCoordinator | 原变量25、100条循环历史、玩家事件前门/怪物条件、同帧防并发；写入成功后递增。BackSpace恢复角色、货币、事件修改、地图发现/回路、音频、消息和跟随。 |
| 47-04 系统API与键盘 | FlashPreferences、FlashKeyboard、ScriptSemantics、CustomDataState | WindowScaler.resize及4→3兼容，标题和日志工具；已有键盘边缘/重复和窗口缩放使用标准Godot。原进程句柄/内存指针不暴露。 |
| 47-05 位图与航拍 | FlashBitmap、FlashMapSnapshot、FlashPresentationState | 原像素/BGRA/混合/蒙版/PNG服务复用；M/U/T/A地图航拍、1/2/4/8缩放、第一页事件与遮挡排序，U输出两层且强制原大小。 |
| 47-06 视频工具 | FlashMoviePlayer、EventInterpreter | 工程资源路径、区域、等待/跳过、停止/暂停/继续；Godot Ogg Theora资源入口。原工程无视频文件或实际事件调用，缺素材/不支持格式明确拒绝。 |
| 47-07 动态与文件访问 | ScriptSemantics、ScriptRuntime、FlashObjectCatalog、FlashValueExtensions及既有数据服务 | DeepClone保留内部图关系且复制实例；通用Game_Object文件构造读已迁移的绑定数据和缺文件默认。有限eval/分派及生成事件/数据表达式沿用已核对行为，剩余新输入明确诊断，不执行任意Ruby。 |
| 47-08 依赖与生命周期 | FLASH_LIFECYCLE_AUDIT_v0.47.md/json | 339槽位、241有内容脚本、144事件片段、113动态位置、27alias声明；分类登记生成、服务适配、排除、历史/覆盖/空实现与缺资源。 |

## 开发入口

生成工程的runtime/scripts对应迁移器templates/runtime/scripts。普通技能仍编辑runtime/generated/flash_skill_catalog.gd；原页面与演出入口见0.46源码说明。

```gdscript
# 由同一个RuntimeState管理，勿创建第二份游戏状态。
var saved = load("res://runtime/scripts/SaveService.gd").save_slot(1, RuntimeState)
var recorded = RuntimeState.flash_history.record()
var undone = RuntimeState.flash_history.undo()

var snapshots = load("res://runtime/scripts/FlashMapSnapshot.gd").new()
snapshots.set_mode("A")
snapshots.set_scale(2)
var exported = snapshots.snap(10) # user://MapSnapshots/Map010.png

# 视频资源需由工程提供。原工程未提供，不能假报播放成功。
var game = RuntimeState.game()
var started = game._flash_movie.play("opening.ogv", true, true)
# GDScript控制器查询status(request_id)，原事件解释器按请求ID等待。
```

## 保存和源边界

旧Godot树形进度仍经schema1校验；新闪翼payload使用对象图，原工程指纹/校验和/备份规则保留。复杂图按节点/元素/深度和文件预算明确拒绝，不裁切。活动图像保存为受尺寸/长度限制的PNG，不保存原DLL指针；任意动态回调、截图正在采集、瞬时传送/页面切换和正在播放的视频仍明确拒绝保存。

原空音乐切换/奖励、固定成就样例、空BUFF/Help、未提供的回路预设/副手、旧0257缺方法路径不补造。缺失默认冻结SE、扫描线/闪回SE、碎屏SE/蒙版继续在实际入口拒绝。闭源DLL的模糊由Godot替代，不能声称逐像素一致。航拍修复源中未定义rect/hue引用并使用拥有的Image，原Ruby保留只读。视频格式依据[Godot官方文档](https://docs.godotengine.org/en/stable/classes/class_videostreamplayer.html)。

## 正式交付

全新正式目标：../output/0.47/final/黎之闪翼（开发中）_Godot。由原rm_template/魔塔样板7630·改经Validator→MigrationPipeline重新迁移。历史0.46、0.45和原RM不改写。导出和核验结果见tests/VERIFICATION_v0.47.md。
