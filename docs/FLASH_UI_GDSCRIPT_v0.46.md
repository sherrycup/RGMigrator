# 闪翼0.46源码结构与开发入口

2026-10-15状态更正：本文列的是已接入页面职责，当前部分页面采用简化的Godot按钮和布局，原图形UI并未完整还原。用户已将原素材/布局/光标/动画与交互还原列入[0.5优化目标](UI_OPTIMIZATION_v0.5.md)；不能以历史阶段勾选或可操作性称为视觉还原完成。

本表对应当前0.46实现。迁移器内的`templates/runtime/scripts/`在生成工程中是`runtime/scripts/`。GDScript是后续开发入口；`legacy/ordered_scripts`保留原加载顺序的Ruby原文，仅作来源查阅。普通战斗与数值业务继续使用0.45同一份实现，没有在页面中复制另一套计算。

## 找到要改的代码

| 原脚本/职责 | GDScript文件 | 修改入口与实际行为 |
| --- | --- | --- |
| 0009/0027绘图、0030/0031图形 | `FlashBitmap.gd`、`FlashShape.gd`、`FlashPalette.gd`、`FlashColor.gd` | H8背景、边框、分割线、鼓起、技能/物品卡框、渐变、圆角、椭圆、图形扫描线和颜色运算。位图持有自己的Image；Cache纹理只读。 |
| 0012/0023位图扩展 | `FlashBitmap.gd`、`FlashTextDrawing.gd` | 反色、色调、蒙版、马赛克、BGRA数据、PNG、原渐变接口；文本移到CanvasItem的`_draw`，含影字、描边、删除线及富文本。Godot替代原DLL；不暴露进程内存地址，模糊效果不宣称与闭源DLL逐像素一致。 |
| 0025/0034素材缓存与RPG显示字段 | `RmxpCache.gd`、`UIResources.gd`、`FlashItemPresets.gd`、`FlashSkillConfig.gd` | 原素材分类、Skills/Faces、按原数据库字段显示名称/分类/说明；缺失资源明确诊断，不补RTP。 |
| 0032/0033/0337显示与启动 | `ProjectGenerator.gd`、`FlashPreferences.gd`、`TransitionRenderer.gd` | 闪翼640×640/60Hz、原字体候选、窗口比例/全屏、截图/过渡的Godot实现。原GDI/窗口EXE由标准引擎API替代。 |
| 0041–0049系统/临时字段/画面/图片/计时器 | `RuntimeState.gd`、`CustomDataState.gd`、`AudioRuntime.gd`、`ScreenState.gd`、`PictureState.gd`、`ScreenRenderer.gd`、`GameTimer.gd` | RuntimeState为真值；脚本草稿校验后一次安装。音频、色调/闪光/震动、50张图片、计时器使用既有事件接口。 |
| 0091–0105人物、事件、地图及表现 | `CharacterMotion.gd`、`CharacterRoute.gd`、`FlashCharacterBridge.gd`、`FlashMapBridge.gd`、`MapCharacter.gd`、`MapEvent.gd`、`PlayerController.gd`、`MapRuntime.gd`、`EventScheduler.gd`、`FlashEnemyMapLabels.gd` | 原60Hz移动/跳跃/动画及自主移动严格频度，事件属性/永久覆盖、通行/镜头/雾/动画；显伤按开关3、原伤害颜色和耐心<3显示，读同一普通预测。 |
| 0108/0109及0245–0251地图半成品 | `FlashFloor.gd`、`FlashRegion.gd`、`FlashMapSystem.gd`、`FlashMapBlock.gd`、`FlashMapCursor.gd`、`FlashMapPreview.gd`、`FlashMapScreen.gd` | 楼层链接、区域、发现/布局/连接/预览和实际M页；空配置与源未完成方法保留。 |
| 0111–0114基础窗口 | `WindowBase.gd`、`WindowSelectable.gd`、`WindowCommand.gd`、`FlashBitmap.gd`、`FlashTextDrawing.gd` | Godot控件承担内容裁切、光标/滚动、命令启用、帮助与文字；源特殊窗口在对应Flash页面中组合。无需重新建立RGSS Window对象。 |
| 0116/0119–0131物品/技能/装备/目标/商店窗口 | `FlashItemPage.gd`、`FlashCastingPage.gd`、`FlashEquipmentPage.gd`、`InventoryScene.gd`、`ShopScene.gd`、`FlashArchivePage.gd` | 选择、帮助、目标与交易展示接统一状态；装备确认走FlashActions，商店走ShopService。0123的旧五槽Getter与最终六槽角色不一致，独立GDS装备页使用最终六槽。 |
| 0132/0133名字/数值输入 | `NameInput.gd`、`DialogueOverlay.gd`、`FlashMessageController.gd` | 名称编辑、整数输入、请求身份、确认/取消与返回。 |
| 0134/0149–0157/0191消息/历史 | `FlashMessageText.gd`、`FlashTextRow.gd`、`FlashMessageBoxState.gd`、`FlashMessageLayout.gd`、`FlashMessageView.gd`、`FlashMessageController.gd`、`FlashMessageMemoryPage.gd` | 原控制码、行度量、名字/头像/位置、打字/暂停/唤醒、提示、历史100/50和真实L入口；旧0134被最终自定义消息路径替代。 |
| 0135/0136/0260调试 | `FlashDebugPage.gd` | 十项分组、开关切换、变量±1/±10及±99999999限幅；非数值变量拒绝数值编辑。开发构建F9及独立入口。 |
| 0139–0145/0265标题/设置/附页 | `FlashTitleScreen.gd`、`FlashConfigPage.gd`、`FlashTitleExtrasPage.gd`、`FlashPreferences.gd`、`RuntimeVersion.gd` | 原七项标题、四难度、背景/标志、音量/显示设置、CD动画和原成就样例；源空切歌/奖励分支保持空。 |
| 0159–0165解释器 | `EventInterpreter.gd`、`EventExecutionContext.gd`、`EventScheduler.gd`、`EventUIBroker.gd`、`ScriptRuntime.gd`、`ScriptSemantics.gd` | 原非战斗指令使用既有执行器；355/655及路线/条件脚本使用生成GDS绑定；八行选择、并行提示、页面/演出等待及失效回调防护。特殊BOSS对应指令路径按用户要求排除。 |
| 0169–0174档案 | `FlashArchiveData.gd`、`FlashArchivePage.gd`、`SaveCodec.gd`、`SaveService.gd` | 档案卡、Tab存读模式、章节/源提示、两位角色数据、352预览内316截图/八帧淡化；JSON内校验截图及展示数据、追加空档案、覆盖备份。读取的是Godot进度，不读取原RM Marshal存档。 |
| 0177–0183物品与九格预设 | `FlashItemPage.gd`、`FlashItemPresets.gd`、`FlashMapShortcuts.gd`、`FlashPlayerHUD.gd` | 原分类/数量/回复和工具CE9；变量4整数Hash九格预设，耗尽保留图标，地图1–9及技能组快捷键。 |
| 0186–0188/0197状态/标题/地图名 | `FlashPlayerHUD.gd`、`FlashMapHUD.gd`、`FlashTopic.gd`、`FlashArchivePage.gd` | 原主援状态/经验/属性/技能卡，换位布局、BUFF空区、九格条独立淡化、16/48/16地图名；Topic原标题ID及八帧8px移动。档案状态读保存快照。 |
| 0198/0200–0203地图菜单与动效 | `FlashMenuScreen.gd`、`MenuCoordinator.gd`、`FlashSceneBackdrop.gd`、`Game.gd` | 原十命令/解锁、对应页面、输入归属、八帧非阻塞模糊、页面返回及HUD恢复。最终装备/成就/合成菜单分支为空，未新增菜单功能。 |
| 0207–0209技能配置 | `FlashSkillConfig.gd`、`FlashSkillPage.gd` | 原四分类/角色标签、被动/追击/1–8回合、替换交换、Tab角色及W/E技能组；实际卡图/说明。 |
| 0215–0221回路 | `FlashBlastic.gd`、`FlashBlasticPage.gd`、`FlashActions.gd` | 原两链/孔位/限制、结晶候选/说明/属性预览与确认装卸；缺原预设明确保留缺口，不补造规则。 |
| 0224–0227笔记 | `FlashNotePage.gd`、`FlashGameplayImporter.gd` | 原五分类解锁/九条样例及case说明，滚动与返回；源空类别保持空。 |
| 0231–0240灵视 | `FlashSightModel.gd`、`FlashSightPage.gd`、`FlashActionOrder.gd` | A入口、聚焦/目标/类、角色有效属性和同一战斗预测，技能/行动条/详情；96帧生命交叉淡化。源BUFF列表为空。 |
| 0254–0260独立场景 | `FlashSceneRegistry.gd`、`FlashSelectionPage.gd`、`FlashItemPage.gd`、`FlashCastingPage.gd`、`FlashEquipmentPage.gd`、`ShopScene.gd`、`FlashDebugPage.gd` | 独立GDS入口及事件`$scene`请求。楼层选择只回变量13，不擅自传送；CP确认id-1/取消main_id按源不同约定保留。 |
| 0270文本流 | `FlashTextStream.gd` | 导出extras内UTF-8文本、标签/行数/END/重开和缺文件false。 |
| 0310/0311演出/碎屏 | `FlashScreenEffects.gd`、`FlashEffectView.gd`、`FlashBrokenScreen.gd` | 黑边、灰度冻结、模糊、扫描线、闪回、旁白、苏醒和碎屏算法；实际异步截图、源帧数/位移/透明度、事件等待和取消。 |
| 0312帮助半成品 | `FlashHelpMessage.gd` | 原透明空影区域保留为实例记录；set_text/update源为空，未创造教程功能。 |
| 0315/0330/0331/0332工具/消散/跟随 | `FlashUtils.gd`、`FlashUnravel.gd`、`FlashScreenEffects.gd`、`FlashFollowers.gd` | 距离/范围/查事件/原文本适配、图像蒙版、实例消散、五格历史及四位跟随者；原作者信息保留。 |

## 可直接继续开发的例子

```gdscript
# 生成工程的Game实例（不要新建第二份RuntimeState）。
var game = RuntimeState.game()
game.show_flash_scene("Scene_CP")
game.show_flash_scene("Scene_Equip", [0, 0])

# 返回请求编号；自己的控制器查询完成，事件解释器会自动等待。
var started = game.play_flash_effect("set_rect", [])
if started.ok:
    var status = RuntimeState.flash_effects.status(started.flash_effect_request)

# 修复了原run_img缺少图片编号的错误，图片使用显式编号入口。
game.unravel_picture(1, [0, 4, 0.5, "RU", "S", false])

# 改普通战斗技能定义仍在原0.45入口。
# runtime/generated/flash_skill_catalog.gd
```

页面展示读取同一角色/库存/开关/变量。业务修改优先使用`FlashActions`、`RuntimeState`或`ScriptRuntime.call_transaction`；不要在state_changed监听中开启嵌套事务。消息和演出只由其所属控制器推进一个时钟，页面不要重复调用模型tick。

## 本版本仍然照实保留的边界

- 0.46不是原全部Ruby代码的最终验收。0.47继续对象关系、跨启动设置/音乐解锁、撤回记录及剩余插件/入口收尾；完整活动消息、演出、消散关系的保存仍属该阶段，0.46会拒绝保存无法还原的活动表现现场。
- 0244/0249/0250是旧地图半成品入口，依赖最终源已不存在的Spriteset_MapSystem或字段；实际使用0248/0251。0262 EnemyDate无外部创建、draw_item为空；0267完整处于块注释；旧窗口/场景的覆盖关系单列，不伪造一个空窗口表示功能成功。
- 0257保留的旧场景调用最终源不存在的skill_can_use?/skill_effect，且Window_Skill已被0207重开。独立GDS浏览页接现有菜单公共事件接口；不存在的旧随机结算不会扣SP或假报成功。0269的历史排序插件继续按0.47收尾。
- 原扫描线/闪回的“静电声2.mp3/静电声.mp3”、默认冻结音效、碎屏crash音效/默认sptx蒙版缺失时，实际入口明确拒绝并报告来源；动画逻辑用内存夹具验证，不将夹具素材写入正式工程。
- 地图半成品、音乐室空方法、固定成就样例、BUFF列表、缺失副手/回路预设保持原状态；特殊BOSS战按用户要求排除。

逐项检查见`tests/VERIFICATION_v0.46.md`；源修正进入生成工程`data/source_corrections.json`。生成单元数量、Ruby原文保留和可执行行为三者分别记录。
