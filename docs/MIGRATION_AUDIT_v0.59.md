# 0.59 剩余迁移缺口审计

0.59整合自查；脚本文件名已移除Flash前缀，Editor_保留。新分辨率窗口位置后续统一调整，用户人工验收待进行。

逐脚本/方法声明定位及职责/入口审计；GDScript重写不承诺每个Ruby方法同名存在。接口/文件存在不是全部行为已验收；行为证据见tests/VERIFICATION_v0.59。

核对339个原脚本槽、2790条方法/alias声明、21条同名覆盖链、738处运行时字面依赖和4077个资源路径。503条为显式标记的词法候选，不能当作完整Ruby语义解析。

本版补齐0026原上层遮挡：走入四向连通屋檐/树冠时原1、2层变为160/255透明度，离开、动态改图、重载正确恢复；地面及新增高层不变。派生缓存只服务绘制，不写存档，原地不重复BFS。

| 序号 | 原脚本 | 分类 | 实际入口/边界 | Godot实现 |
| --- | --- | --- | --- | --- |
| 0001 | Test | 源空槽/注释 | 原源空槽/注释； |  |
| 0002 | ▼ 全局设定 | 源空槽/注释 | 原源空槽/注释； |  |
| 0003 | Global | 已实现 | 原全局别名、项目变量及Godot输入/配置服务；不提供任意DLL调用或原生地址；已知用途由Godot服务替代。 | ScriptSemantics.gd, CustomDataState.gd, Preferences.gd, Keyboard.gd, ValueExtensions.gd |
| 0004 | Global_Variables | 已实现 | 原全局别名、项目变量及Godot输入/配置服务；不提供任意DLL调用或原生地址；已知用途由Godot服务替代。 | ScriptSemantics.gd, CustomDataState.gd, Preferences.gd, Keyboard.gd, ValueExtensions.gd |
| 0005 | Universal_Bind | 已实现 | 原全局别名、项目变量及Godot输入/配置服务；不提供任意DLL调用或原生地址；已知用途由Godot服务替代。 | ScriptSemantics.gd, CustomDataState.gd, Preferences.gd, Keyboard.gd, ValueExtensions.gd |
| 0006 | 全局定义 | 已实现 | 原全局别名、项目变量及Godot输入/配置服务；不提供任意DLL调用或原生地址；已知用途由Godot服务替代。 | ScriptSemantics.gd, CustomDataState.gd, Preferences.gd, Keyboard.gd, ValueExtensions.gd |
| 0007 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0008 | ▼ 系统预设 | 源空槽/注释 | 原源空槽/注释； |  |
| 0009 | Sotrage | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0010 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0011 | ▼ 插件 | 源空槽/注释 | 原源空槽/注释； |  |
| 0012 | []TKTK_Bitmap | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0013 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0014 | ▼ 测试集 | 源空槽/注释 | 原源空槽/注释； |  |
| 0015 | Test | 源空槽/注释 | 原源空槽/注释； |  |
| 0016 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0017 | ▼ RGSS 追加 | 源空槽/注释 | 原源空槽/注释； |  |
| 0018 | Object | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0019 | Array | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0020 | String | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0021 | Numeric | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0022 | Color | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0023 | Bitmap | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0024 | Hash | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0025 | RPG::Cache | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0026 | Tilemap | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0027 | Bitmap绘图追加 | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0028 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0029 | ▼ GDI追加 | 源空槽/注释 | 原源空槽/注释； |  |
| 0030 | Shape | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0031 | Hexagon | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0032 | Graphics | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0033 | WindowScaler | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0034 | RPG追加 | 已实现 | 标题/功能页/Message/地图实际绘制、缓存及图片工具；原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。 | Bitmap.gd, TextDrawing.gd, Shape.gd, Color.gd, Palette.gd, ValueExtensions.gd, ScriptSemantics.gd, RmxpCache.gd, MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapSnapshot.gd, Preferences.gd |
| 0035 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0036 | ▼ 数据 | 源空槽/注释 | 原源空槽/注释； |  |
| 0037 | DataBase | 已实现 | 迁移器提取常量；运行楼层与区域读取同一数据； | Floor.gd, Region.gd, RuntimeData.gd |
| 0038 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0039 | ▼ 系统 | 源空槽/注释 | 原源空槽/注释； |  |
| 0040 | ->Sotrage | 已实现 | 标题设置、音乐解锁及跨启动偏好；音乐实际切曲和成就奖励在原源为空；不新增。 | Preferences.gd, FileStore.gd, ConfigPage.gd, TitleExtrasPage.gd, AudioRuntime.gd |
| 0041 | Game_Temp | 已实现 | RuntimeState、地图/事件指令及保存现场； | RuntimeState.gd, CustomDataState.gd, AudioRuntime.gd, ScreenState.gd, PictureState.gd, ScreenRenderer.gd, GameTimer.gd, CharacterBridge.gd, MapBridge.gd |
| 0042 | Game_System 1 | 已实现 | RuntimeState、地图/事件指令及保存现场； | RuntimeState.gd, CustomDataState.gd, AudioRuntime.gd, ScreenState.gd, PictureState.gd, ScreenRenderer.gd, GameTimer.gd, CharacterBridge.gd, MapBridge.gd |
| 0043 | Game_System 2 | 已实现 | RuntimeState、地图/事件指令及保存现场； | RuntimeState.gd, CustomDataState.gd, AudioRuntime.gd, ScreenState.gd, PictureState.gd, ScreenRenderer.gd, GameTimer.gd, CharacterBridge.gd, MapBridge.gd |
| 0044 | Game_Screen | 已实现 | RuntimeState、地图/事件指令及保存现场； | RuntimeState.gd, CustomDataState.gd, AudioRuntime.gd, ScreenState.gd, PictureState.gd, ScreenRenderer.gd, GameTimer.gd, CharacterBridge.gd, MapBridge.gd |
| 0045 | Game_Picture | 已实现 | RuntimeState、地图/事件指令及保存现场； | RuntimeState.gd, CustomDataState.gd, AudioRuntime.gd, ScreenState.gd, PictureState.gd, ScreenRenderer.gd, GameTimer.gd, CharacterBridge.gd, MapBridge.gd |
| 0046 | Game_Config | 已实现 | 标题设置、音乐解锁及跨启动偏好；音乐实际切曲和成就奖励在原源为空；不新增。 | Preferences.gd, FileStore.gd, ConfigPage.gd, TitleExtrasPage.gd, AudioRuntime.gd |
| 0047 | Game_Music | 已实现 | 标题设置、音乐解锁及跨启动偏好；音乐实际切曲和成就奖励在原源为空；不新增。 | Preferences.gd, FileStore.gd, ConfigPage.gd, TitleExtrasPage.gd, AudioRuntime.gd |
| 0048 | Sprite_Picture | 已实现 | RuntimeState、地图/事件指令及保存现场； | RuntimeState.gd, CustomDataState.gd, AudioRuntime.gd, ScreenState.gd, PictureState.gd, ScreenRenderer.gd, GameTimer.gd, CharacterBridge.gd, MapBridge.gd |
| 0049 | Sprite_Timer | 已实现 | RuntimeState、地图/事件指令及保存现场； | RuntimeState.gd, CustomDataState.gd, AudioRuntime.gd, ScreenState.gd, PictureState.gd, ScreenRenderer.gd, GameTimer.gd, CharacterBridge.gd, MapBridge.gd |
| 0050 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0051 | ▼ 游戏对象 | 源空槽/注释 | 原源空槽/注释； |  |
| 0052 | ->Sotrage | 已实现 | 物品页/九格快捷栏/公共事件9及同一背包；原无Deputy定义及部分exdata；不存在的数据明确拒绝，不伪造副手。 | ItemEffects.gd, ObjectCatalog.gd, Actions.gd, ItemPresets.gd, CustomDataState.gd |
| 0053 | Game_Object | 已实现 | 物品页/九格快捷栏/公共事件9及同一背包；原无Deputy定义及部分exdata；不存在的数据明确拒绝，不伪造副手。 | ItemEffects.gd, ObjectCatalog.gd, Actions.gd, ItemPresets.gd, CustomDataState.gd |
| 0054 | Game_Item | 已实现 | 物品页/九格快捷栏/公共事件9及同一背包；原无Deputy定义及部分exdata；不存在的数据明确拒绝，不伪造副手。 | ItemEffects.gd, ObjectCatalog.gd, Actions.gd, ItemPresets.gd, CustomDataState.gd |
| 0055 | Game_Weapon | 已实现 | 物品页/九格快捷栏/公共事件9及同一背包；原无Deputy定义及部分exdata；不存在的数据明确拒绝，不伪造副手。 | ItemEffects.gd, ObjectCatalog.gd, Actions.gd, ItemPresets.gd, CustomDataState.gd |
| 0056 | Game_Armor | 已实现 | 物品页/九格快捷栏/公共事件9及同一背包；原无Deputy定义及部分exdata；不存在的数据明确拒绝，不伪造副手。 | ItemEffects.gd, ObjectCatalog.gd, Actions.gd, ItemPresets.gd, CustomDataState.gd |
| 0057 | Game_Ornament | 已实现 | 物品页/九格快捷栏/公共事件9及同一背包；原无Deputy定义及部分exdata；不存在的数据明确拒绝，不伪造副手。 | ItemEffects.gd, ObjectCatalog.gd, Actions.gd, ItemPresets.gd, CustomDataState.gd |
| 0058 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0059 | ▼ 战斗相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0060 | ->Sotrage | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0061 | ->Storage(技能文本) | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0062 | Skill 1 | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0063 | Skill 2 | 源空槽/注释 | 原源空槽/注释； |  |
| 0064 | Skill 3 | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0065 | Game_Battler 1 | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0066 | Game_Battler 2 | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0067 | Game_Battler 3 | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0068 | Game_Actor 1 | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0069 | Game_Actor 2 | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0070 | Game_Enemy 1 | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0071 | Game_Enemy 2 | 已实现 | 普通魔塔计算、角色/敌人属性与技能配置；原缺exdata及未实现魔法分类保留。 | Game_ActorState.gd, EnemyState.gd, BattlerRules.gd, ObjectCatalog.gd, BattleRegistry.gd, BattleSimulator.gd, SkillConfig.gd, Blastic.gd |
| 0072 | BattleSystem | 已实现 | 公共事件1→普通魔塔战斗与地图显伤/灵视同一预测；0075/0076旧战斗数据接口保留兼容；特殊BOSS与RM回合制战斗排除。 | BattleRegistry.gd, BattleSimulator.gd, Gameplay.gd, Actions.gd, Game_ActorState.gd, EnemyState.gd, ActionOrder.gd |
| 0073 | SkillRegistry | 已实现 | 公共事件1→普通魔塔战斗与地图显伤/灵视同一预测；0075/0076旧战斗数据接口保留兼容；特殊BOSS与RM回合制战斗排除。 | BattleRegistry.gd, BattleSimulator.gd, Gameplay.gd, Actions.gd, Game_ActorState.gd, EnemyState.gd, ActionOrder.gd |
| 0074 | ●█Game_Enemy 3 | 源空槽/注释 | 原源空槽/注释； |  |
| 0075 | Battle_Data | 已实现 | 公共事件1→普通魔塔战斗与地图显伤/灵视同一预测；0075/0076旧战斗数据接口保留兼容；特殊BOSS与RM回合制战斗排除。 | BattleRegistry.gd, BattleSimulator.gd, Gameplay.gd, Actions.gd, Game_ActorState.gd, EnemyState.gd, ActionOrder.gd |
| 0076 | Delay_Ctrl | 已实现 | 公共事件1→普通魔塔战斗与地图显伤/灵视同一预测；0075/0076旧战斗数据接口保留兼容；特殊BOSS与RM回合制战斗排除。 | BattleRegistry.gd, BattleSimulator.gd, Gameplay.gd, Actions.gd, Game_ActorState.gd, EnemyState.gd, ActionOrder.gd |
| 0077 | ▼ 队列 | 源空槽/注释 | 原源空槽/注释； |  |
| 0078 | ▲Game_Party | 已实现 | 唯一角色注册表、队伍、货币及地图敌人； | RuntimeState.gd, CustomDataState.gd, Game_ActorState.gd, EnemyState.gd, ObjectCatalog.gd, Followers.gd, Floor.gd, Blastic.gd |
| 0079 | Game_Troop | 已实现 | 唯一角色注册表、队伍、货币及地图敌人； | RuntimeState.gd, CustomDataState.gd, Game_ActorState.gd, EnemyState.gd, ObjectCatalog.gd, Followers.gd, Floor.gd, Blastic.gd |
| 0080 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0081 | ▼ 系统排列 | 源空槽/注释 | 原源空槽/注释； |  |
| 0082 | Game_Switches | 已实现 | 唯一角色注册表、队伍、货币及地图敌人； | RuntimeState.gd, CustomDataState.gd, Game_ActorState.gd, EnemyState.gd, ObjectCatalog.gd, Followers.gd, Floor.gd, Blastic.gd |
| 0083 | Game_Variables | 已实现 | 唯一角色注册表、队伍、货币及地图敌人； | RuntimeState.gd, CustomDataState.gd, Game_ActorState.gd, EnemyState.gd, ObjectCatalog.gd, Followers.gd, Floor.gd, Blastic.gd |
| 0084 | Game_SelfSwitches | 已实现 | 唯一角色注册表、队伍、货币及地图敌人； | RuntimeState.gd, CustomDataState.gd, Game_ActorState.gd, EnemyState.gd, ObjectCatalog.gd, Followers.gd, Floor.gd, Blastic.gd |
| 0085 | Game_Actors | 已实现 | 唯一角色注册表、队伍、货币及地图敌人； | RuntimeState.gd, CustomDataState.gd, Game_ActorState.gd, EnemyState.gd, ObjectCatalog.gd, Followers.gd, Floor.gd, Blastic.gd |
| 0086 | Game_Equipment | 已实现 | 唯一角色注册表、队伍、货币及地图敌人； | RuntimeState.gd, CustomDataState.gd, Game_ActorState.gd, EnemyState.gd, ObjectCatalog.gd, Followers.gd, Floor.gd, Blastic.gd |
| 0087 | Game_Troops | 已实现 | 唯一角色注册表、队伍、货币及地图敌人； | RuntimeState.gd, CustomDataState.gd, Game_ActorState.gd, EnemyState.gd, ObjectCatalog.gd, Followers.gd, Floor.gd, Blastic.gd |
| 0088 | Game_Blastics | 已实现 | 唯一角色注册表、队伍、货币及地图敌人； | RuntimeState.gd, CustomDataState.gd, Game_ActorState.gd, EnemyState.gd, ObjectCatalog.gd, Followers.gd, Floor.gd, Blastic.gd |
| 0089 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0090 | ▼ 事件相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0091 | ->Sotrage | 已实现 | 地图人物运动、事件刷新/覆盖、跟随与显伤； | CharacterMotion.gd, CharacterRoute.gd, MapCharacter.gd, MapEvent.gd, PlayerController.gd, EventScheduler.gd, CharacterBridge.gd, MapBridge.gd, Followers.gd, EnemyMapLabels.gd |
| 0092 | Game_CommonEvent | 已实现 | 地图人物运动、事件刷新/覆盖、跟随与显伤； | CharacterMotion.gd, CharacterRoute.gd, MapCharacter.gd, MapEvent.gd, PlayerController.gd, EventScheduler.gd, CharacterBridge.gd, MapBridge.gd, Followers.gd, EnemyMapLabels.gd |
| 0093 | Game_Character 1 | 已实现 | 地图人物运动、事件刷新/覆盖、跟随与显伤； | CharacterMotion.gd, CharacterRoute.gd, MapCharacter.gd, MapEvent.gd, PlayerController.gd, EventScheduler.gd, CharacterBridge.gd, MapBridge.gd, Followers.gd, EnemyMapLabels.gd |
| 0094 | Game_Character 2 | 已实现 | 地图人物运动、事件刷新/覆盖、跟随与显伤； | CharacterMotion.gd, CharacterRoute.gd, MapCharacter.gd, MapEvent.gd, PlayerController.gd, EventScheduler.gd, CharacterBridge.gd, MapBridge.gd, Followers.gd, EnemyMapLabels.gd |
| 0095 | Game_Character 3 | 已实现 | 地图人物运动、事件刷新/覆盖、跟随与显伤； | CharacterMotion.gd, CharacterRoute.gd, MapCharacter.gd, MapEvent.gd, PlayerController.gd, EventScheduler.gd, CharacterBridge.gd, MapBridge.gd, Followers.gd, EnemyMapLabels.gd |
| 0096 | Game_Event | 已实现 | 地图人物运动、事件刷新/覆盖、跟随与显伤； | CharacterMotion.gd, CharacterRoute.gd, MapCharacter.gd, MapEvent.gd, PlayerController.gd, EventScheduler.gd, CharacterBridge.gd, MapBridge.gd, Followers.gd, EnemyMapLabels.gd |
| 0097 | Game_Player 1 | 已实现 | 地图人物运动、事件刷新/覆盖、跟随与显伤； | CharacterMotion.gd, CharacterRoute.gd, MapCharacter.gd, MapEvent.gd, PlayerController.gd, EventScheduler.gd, CharacterBridge.gd, MapBridge.gd, Followers.gd, EnemyMapLabels.gd |
| 0098 | Game_Player 2 | 已实现 | 地图人物运动、事件刷新/覆盖、跟随与显伤； | CharacterMotion.gd, CharacterRoute.gd, MapCharacter.gd, MapEvent.gd, PlayerController.gd, EventScheduler.gd, CharacterBridge.gd, MapBridge.gd, Followers.gd, EnemyMapLabels.gd |
| 0099 | ▲Sprite_Character | 已实现 | 地图人物运动、事件刷新/覆盖、跟随与显伤； | CharacterMotion.gd, CharacterRoute.gd, MapCharacter.gd, MapEvent.gd, PlayerController.gd, EventScheduler.gd, CharacterBridge.gd, MapBridge.gd, Followers.gd, EnemyMapLabels.gd |
| 0100 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0101 | ▼ 地图相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0102 | ->Sotrage | 已实现 | 地图加载/通行/镜头/雾、图块覆盖和楼层链接； | MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapCamera.gd, MapEffectsState.gd, MapEffectsRenderer.gd, MapBridge.gd, Floor.gd, Region.gd |
| 0103 | ▲●Game_Map 1 | 已实现 | 地图加载/通行/镜头/雾、图块覆盖和楼层链接； | MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapCamera.gd, MapEffectsState.gd, MapEffectsRenderer.gd, MapBridge.gd, Floor.gd, Region.gd |
| 0104 | Game_Map 2 | 已实现 | 地图加载/通行/镜头/雾、图块覆盖和楼层链接； | MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapCamera.gd, MapEffectsState.gd, MapEffectsRenderer.gd, MapBridge.gd, Floor.gd, Region.gd |
| 0105 | Spriteset_Map | 已实现 | 地图加载/通行/镜头/雾、图块覆盖和楼层链接； | MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapCamera.gd, MapEffectsState.gd, MapEffectsRenderer.gd, MapBridge.gd, Floor.gd, Region.gd |
| 0106 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0107 | ▼ 楼层相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0108 | Game_Floor | 已实现 | 地图加载/通行/镜头/雾、图块覆盖和楼层链接； | MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapCamera.gd, MapEffectsState.gd, MapEffectsRenderer.gd, MapBridge.gd, Floor.gd, Region.gd |
| 0109 | Game_Region | 已实现 | 地图加载/通行/镜头/雾、图块覆盖和楼层链接； | MapRuntime.gd, MapTileRow.gd, MapOcclusion.gd, MapCamera.gd, MapEffectsState.gd, MapEffectsRenderer.gd, MapBridge.gd, Floor.gd, Region.gd |
| 0110 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0111 | ▲Window_Base | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0112 | Window_Selectable | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0113 | Window_Command | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0114 | Window_Help | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0115 | Window_Gold | 源空槽/注释 | 原源空槽/注释； |  |
| 0116 | ▲Window_Item | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0117 | ★Window_Flytofloor | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0118 | ★Window_CP | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0119 | Window_Skill | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0120 | Window_SkillStatus | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0121 | Window_Target | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0122 | ▲Window_EquipLeft | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0123 | Window_EquipRight | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0124 | ▲Window_EquipItem | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0125 | Window_Status | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0126 | ▲Window_SaveFile | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0127 | Window_ShopCommand_New | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0128 | Window_ShopBuy | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0129 | Window_ShopSell | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0130 | Window_ShopNumber | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0131 | Window_ShopStatus | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0132 | Window_NameEdit | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0133 | ▲Window_InputNumber | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0134 | ▲Window_Message | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0135 | Window_DebugLeft | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0136 | Window_DebugRight | 已实现 | 最终功能窗口/事件名称数字输入及兼容独立页；0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。 | WindowBase.gd, WindowSelectable.gd, WindowCommand.gd, WindowDrawing.gd, PageSurface.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, SelectionPage.gd, ArchivePage.gd, ShopScene.gd, NameInput.gd, DialogueOverlay.gd, MessageController.gd, DebugPage.gd |
| 0137 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0138 | ▼ 标题相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0139 | ▲Scene_Title | 已实现 | Title→七命令、四难度、设置、音乐/成就附页；音乐切曲/奖励原为空；成就仅原固定样例。 | TitleScreen.gd, TitleLayout.gd, ConfigPage.gd, TitleExtrasPage.gd, Preferences.gd |
| 0140 | Window_BackGround | 已实现 | Title→七命令、四难度、设置、音乐/成就附页；音乐切曲/奖励原为空；成就仅原固定样例。 | TitleScreen.gd, TitleLayout.gd, ConfigPage.gd, TitleExtrasPage.gd, Preferences.gd |
| 0141 | Window_Mode | 已实现 | Title→七命令、四难度、设置、音乐/成就附页；音乐切曲/奖励原为空；成就仅原固定样例。 | TitleScreen.gd, TitleLayout.gd, ConfigPage.gd, TitleExtrasPage.gd, Preferences.gd |
| 0142 | Window_Title | 已实现 | Title→七命令、四难度、设置、音乐/成就附页；音乐切曲/奖励原为空；成就仅原固定样例。 | TitleScreen.gd, TitleLayout.gd, ConfigPage.gd, TitleExtrasPage.gd, Preferences.gd |
| 0143 | Window_Config | 已实现 | Title→七命令、四难度、设置、音乐/成就附页；音乐切曲/奖励原为空；成就仅原固定样例。 | TitleScreen.gd, TitleLayout.gd, ConfigPage.gd, TitleExtrasPage.gd, Preferences.gd |
| 0144 | Window_Music | 已实现 | Title→七命令、四难度、设置、音乐/成就附页；音乐切曲/奖励原为空；成就仅原固定样例。 | TitleScreen.gd, TitleLayout.gd, ConfigPage.gd, TitleExtrasPage.gd, Preferences.gd |
| 0145 | Window_Merit | 已实现 | Title→七命令、四难度、设置、音乐/成就附页；音乐切曲/奖励原为空；成就仅原固定样例。 | TitleScreen.gd, TitleLayout.gd, ConfigPage.gd, TitleExtrasPage.gd, Preferences.gd |
| 0146 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0147 | ▼ 信息相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0148 | ->Storage | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0149 | Message 1 | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0150 | Message 2 | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0151 | Message::TextRow | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0152 | Message::TextBox 1 | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0153 | Message::TextBox 2 | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0154 | Message::HintBox 1 | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0155 | Message::HintBox 2 | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0156 | Message::Words | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0157 | Message_Memory | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0158 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0159 | Interpreter 1 | 已实现 | 真实355/655、111条件、路线45正文及非战斗事件指令；301/601—603及331—340原生回合制战斗指令按既有范围排除；旧Scene_Menu的有效菜单职责由最终地图菜单承担。 | EventInterpreter.gd, EventExecutionContext.gd, EventScheduler.gd, EventUIBroker.gd, NativeEventContext.gd, NativeEventTask.gd, NativeScriptSource.gd, ScriptRuntime.gd, MenuCoordinator.gd |
| 0160 | Interpreter 2 | 已实现 | 真实355/655、111条件、路线45正文及非战斗事件指令；301/601—603及331—340原生回合制战斗指令按既有范围排除；旧Scene_Menu的有效菜单职责由最终地图菜单承担。 | EventInterpreter.gd, EventExecutionContext.gd, EventScheduler.gd, EventUIBroker.gd, NativeEventContext.gd, NativeEventTask.gd, NativeScriptSource.gd, ScriptRuntime.gd, MenuCoordinator.gd |
| 0161 | Interpreter 3 | 已实现 | 真实355/655、111条件、路线45正文及非战斗事件指令；301/601—603及331—340原生回合制战斗指令按既有范围排除；旧Scene_Menu的有效菜单职责由最终地图菜单承担。 | EventInterpreter.gd, EventExecutionContext.gd, EventScheduler.gd, EventUIBroker.gd, NativeEventContext.gd, NativeEventTask.gd, NativeScriptSource.gd, ScriptRuntime.gd, MenuCoordinator.gd |
| 0162 | Interpreter 4 | 已实现 | 真实355/655、111条件、路线45正文及非战斗事件指令；301/601—603及331—340原生回合制战斗指令按既有范围排除；旧Scene_Menu的有效菜单职责由最终地图菜单承担。 | EventInterpreter.gd, EventExecutionContext.gd, EventScheduler.gd, EventUIBroker.gd, NativeEventContext.gd, NativeEventTask.gd, NativeScriptSource.gd, ScriptRuntime.gd, MenuCoordinator.gd |
| 0163 | ▲Interpreter 5 | 已实现 | 真实355/655、111条件、路线45正文及非战斗事件指令；301/601—603及331—340原生回合制战斗指令按既有范围排除；旧Scene_Menu的有效菜单职责由最终地图菜单承担。 | EventInterpreter.gd, EventExecutionContext.gd, EventScheduler.gd, EventUIBroker.gd, NativeEventContext.gd, NativeEventTask.gd, NativeScriptSource.gd, ScriptRuntime.gd, MenuCoordinator.gd |
| 0164 | Interpreter 6 | 已实现 | 真实355/655、111条件、路线45正文及非战斗事件指令；301/601—603及331—340原生回合制战斗指令按既有范围排除；旧Scene_Menu的有效菜单职责由最终地图菜单承担。 | EventInterpreter.gd, EventExecutionContext.gd, EventScheduler.gd, EventUIBroker.gd, NativeEventContext.gd, NativeEventTask.gd, NativeScriptSource.gd, ScriptRuntime.gd, MenuCoordinator.gd |
| 0165 | Interpreter 7 | 已实现 | 真实355/655、111条件、路线45正文及非战斗事件指令；301/601—603及331—340原生回合制战斗指令按既有范围排除；旧Scene_Menu的有效菜单职责由最终地图菜单承担。 | EventInterpreter.gd, EventExecutionContext.gd, EventScheduler.gd, EventUIBroker.gd, NativeEventContext.gd, NativeEventTask.gd, NativeScriptSource.gd, ScriptRuntime.gd, MenuCoordinator.gd |
| 0166 | ▲Scene_Menu | 源未完成 | 真实355/655、111条件、路线45正文及非战斗事件指令；旧独立菜单仍引用最终不存在的Scene_Save/Scene_Load2/Scene_EnemyView；实际事件351和地图输入由最终地图菜单承担，不声称旧类可独立运行。 | EventInterpreter.gd, EventExecutionContext.gd, EventScheduler.gd, EventUIBroker.gd, NativeEventContext.gd, NativeEventTask.gd, NativeScriptSource.gd, ScriptRuntime.gd, MenuCoordinator.gd |
| 0167 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0168 | ▼ 档案相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0169 | Game_FileData | 已实现 | 标题继续、地图/事件存读档、备份确认；不读RM Marshal旧档；图结构校验后才恢复。 | ArchiveData.gd, ArchivePage.gd, ArchiveView.gd, SaveService.gd, SaveCodec.gd, SaveGraph.gd, FileStore.gd, SaveLoadProgress.gd |
| 0170 | Window_FileChapter | 已实现 | 标题继续、地图/事件存读档、备份确认；不读RM Marshal旧档；图结构校验后才恢复。 | ArchiveData.gd, ArchivePage.gd, ArchiveView.gd, SaveService.gd, SaveCodec.gd, SaveGraph.gd, FileStore.gd, SaveLoadProgress.gd |
| 0171 | Window_FileKind | 已实现 | 标题继续、地图/事件存读档、备份确认；不读RM Marshal旧档；图结构校验后才恢复。 | ArchiveData.gd, ArchivePage.gd, ArchiveView.gd, SaveService.gd, SaveCodec.gd, SaveGraph.gd, FileStore.gd, SaveLoadProgress.gd |
| 0172 | Window_MapSnap | 已实现 | 标题继续、地图/事件存读档、备份确认；不读RM Marshal旧档；图结构校验后才恢复。 | ArchiveData.gd, ArchivePage.gd, ArchiveView.gd, SaveService.gd, SaveCodec.gd, SaveGraph.gd, FileStore.gd, SaveLoadProgress.gd |
| 0173 | Window_File | 已实现 | 标题继续、地图/事件存读档、备份确认；不读RM Marshal旧档；图结构校验后才恢复。 | ArchiveData.gd, ArchivePage.gd, ArchiveView.gd, SaveService.gd, SaveCodec.gd, SaveGraph.gd, FileStore.gd, SaveLoadProgress.gd |
| 0174 | Window_FileTips | 已实现 | 标题继续、地图/事件存读档、备份确认；不读RM Marshal旧档；图结构校验后才恢复。 | ArchiveData.gd, ArchivePage.gd, ArchiveView.gd, SaveService.gd, SaveCodec.gd, SaveGraph.gd, FileStore.gd, SaveLoadProgress.gd |
| 0175 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0176 | ▼ 道具相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0177 | Window_ItemCategory | 已实现 | 最终0183九格预设与菜单物品；0182旧八格不是当前入口； | ItemPage.gd, ItemView.gd, ItemPresets.gd, MapShortcuts.gd, PlayerHUD.gd, ItemEffects.gd |
| 0178 | Window_ItemHelp | 已实现 | 最终0183九格预设与菜单物品；0182旧八格不是当前入口； | ItemPage.gd, ItemView.gd, ItemPresets.gd, MapShortcuts.gd, PlayerHUD.gd, ItemEffects.gd |
| 0179 | Window_ItemDesc | 已实现 | 最终0183九格预设与菜单物品；0182旧八格不是当前入口； | ItemPage.gd, ItemView.gd, ItemPresets.gd, MapShortcuts.gd, PlayerHUD.gd, ItemEffects.gd |
| 0180 | Window_Item | 已实现 | 最终0183九格预设与菜单物品；0182旧八格不是当前入口； | ItemPage.gd, ItemView.gd, ItemPresets.gd, MapShortcuts.gd, PlayerHUD.gd, ItemEffects.gd |
| 0181 | Window_Gold | 已实现 | 最终0183九格预设与菜单物品；0182旧八格不是当前入口； | ItemPage.gd, ItemView.gd, ItemPresets.gd, MapShortcuts.gd, PlayerHUD.gd, ItemEffects.gd |
| 0182 | Window_ItemConfig | 已实现 | 最终0183九格预设与菜单物品；0182旧八格不是当前入口； | ItemPage.gd, ItemView.gd, ItemPresets.gd, MapShortcuts.gd, PlayerHUD.gd, ItemEffects.gd |
| 0183 | ※Window_ItemBar | 已实现 | 最终0183九格预设与菜单物品；0182旧八格不是当前入口； | ItemPage.gd, ItemView.gd, ItemPresets.gd, MapShortcuts.gd, PlayerHUD.gd, ItemEffects.gd |
| 0184 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0185 | ▼ 通用窗口 | 源空槽/注释 | 原源空槽/注释； |  |
| 0186 | Window_State | 已实现 | 地图HUD、地图名、菜单状态/五色货币与锁定；BUFF显示空区按原样保留；0196废弃实现不作为最终入口。 | PlayerHUD.gd, MapHUD.gd, Topic.gd, MenuScreen.gd, MenuModel.gd, MenuPages.gd, WindowDrawing.gd |
| 0187 | Window_Topic | 已实现 | 地图HUD、地图名、菜单状态/五色货币与锁定；BUFF显示空区按原样保留；0196废弃实现不作为最终入口。 | PlayerHUD.gd, MapHUD.gd, Topic.gd, MenuScreen.gd, MenuModel.gd, MenuPages.gd, WindowDrawing.gd |
| 0188 | Window_MapName | 已实现 | 地图HUD、地图名、菜单状态/五色货币与锁定；BUFF显示空区按原样保留；0196废弃实现不作为最终入口。 | PlayerHUD.gd, MapHUD.gd, Topic.gd, MenuScreen.gd, MenuModel.gd, MenuPages.gd, WindowDrawing.gd |
| 0189 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0190 | ▼ 控制信息 | 源空槽/注释 | 原源空槽/注释； |  |
| 0191 | Message_Controller | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0192 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0193 | 药品库 | 已实现 | 事件消息与选项/数字/并行提示/历史，普通地图L入口；源40Hz编写时间通过边界换秒，表现只有一个控制时钟。 | MessageText.gd, MessageLayout.gd, MessageView.gd, MessageController.gd, MessageBoxState.gd, TextRow.gd, MessageMemoryPage.gd, ItemEffects.gd |
| 0194 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0195 | ▼ 状态、菜单 | 源空槽/注释 | 原源空槽/注释； |  |
| 0196 | ■●Window_PlayerData(废弃) | 源空槽/注释 | 原源空槽/注释； |  |
| 0197 | ■●Window_PlayerData | 已实现 | 地图HUD、地图名、菜单状态/五色货币与锁定；BUFF显示空区按原样保留；0196废弃实现不作为最终入口。 | PlayerHUD.gd, MapHUD.gd, Topic.gd, MenuScreen.gd, MenuModel.gd, MenuPages.gd, WindowDrawing.gd |
| 0198 | △Window_MenuCommand | 已实现 | 地图HUD、地图名、菜单状态/五色货币与锁定；BUFF显示空区按原样保留；0196废弃实现不作为最终入口。 | PlayerHUD.gd, MapHUD.gd, Topic.gd, MenuScreen.gd, MenuModel.gd, MenuPages.gd, WindowDrawing.gd |
| 0199 | ▲Scene_Map | 源空槽/注释 | 原源空槽/注释； |  |
| 0200 | ▲Scene_Map 1 | 已实现 | 真实地图输入→菜单/功能页/灵视/地图/独立事件页→同一地图；装备/成就/合成主菜单最终分支为空，不新增业务。 | Game.gd, MenuCoordinator.gd, MapShortcuts.gd, PlayerHUD.gd, SceneBackdrop.gd, SightPage.gd, MapScreen.gd, SceneRegistry.gd |
| 0201 | ▲Scene_Map 2 | 已实现 | 真实地图输入→菜单/功能页/灵视/地图/独立事件页→同一地图；装备/成就/合成主菜单最终分支为空，不新增业务。 | Game.gd, MenuCoordinator.gd, MapShortcuts.gd, PlayerHUD.gd, SceneBackdrop.gd, SightPage.gd, MapScreen.gd, SceneRegistry.gd |
| 0202 | ▲Scene_Map 3 | 已实现 | 真实地图输入→菜单/功能页/灵视/地图/独立事件页→同一地图；装备/成就/合成主菜单最终分支为空，不新增业务。 | Game.gd, MenuCoordinator.gd, MapShortcuts.gd, PlayerHUD.gd, SceneBackdrop.gd, SightPage.gd, MapScreen.gd, SceneRegistry.gd |
| 0203 | ▲Scene_Map 4 | 已实现 | 真实地图输入→菜单/功能页/灵视/地图/独立事件页→同一地图；装备/成就/合成主菜单最终分支为空，不新增业务。 | Game.gd, MenuCoordinator.gd, MapShortcuts.gd, PlayerHUD.gd, SceneBackdrop.gd, SightPage.gd, MapScreen.gd, SceneRegistry.gd |
| 0204 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0205 | ▼ 技能相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0206 | Window_SkillConfig | 源空槽/注释 | 原源空槽/注释； |  |
| 0207 | Window_Skill | 已实现 | 技能分类、回合装配、Tab角色、技能组和退出角色顺序；魔法分类原未实现；0206旧窗口未在最终地图创建。 | SkillPage.gd, SkillConfig.gd, SkillView.gd, PlayerHUD.gd |
| 0208 | Window_SkillHelp | 已实现 | 技能分类、回合装配、Tab角色、技能组和退出角色顺序；魔法分类原未实现；0206旧窗口未在最终地图创建。 | SkillPage.gd, SkillConfig.gd, SkillView.gd, PlayerHUD.gd |
| 0209 | Window_SkillCategory | 已实现 | 技能分类、回合装配、Tab角色、技能组和退出角色顺序；魔法分类原未实现；0206旧窗口未在最终地图创建。 | SkillPage.gd, SkillConfig.gd, SkillView.gd, PlayerHUD.gd |
| 0210 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0211 | ▼ Orbment相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0212 | ->Storage(结晶回路追加定义) | 已实现 | 原地之魔盘、两链/孔位/锁定/属性与候选预览确认；原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。 | Blastic.gd, BlasticPage.gd, BlasticView.gd, Actions.gd |
| 0213 | ->Storage | 已实现 | 原地之魔盘、两链/孔位/锁定/属性与候选预览确认；原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。 | Blastic.gd, BlasticPage.gd, BlasticView.gd, Actions.gd |
| 0214 | Game_Blastic | 已实现 | 原地之魔盘、两链/孔位/锁定/属性与候选预览确认；原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。 | Blastic.gd, BlasticPage.gd, BlasticView.gd, Actions.gd |
| 0215 | Window_Blastic | 已实现 | 原地之魔盘、两链/孔位/锁定/属性与候选预览确认；原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。 | Blastic.gd, BlasticPage.gd, BlasticView.gd, Actions.gd |
| 0216 | Window_BlasticAtrri | 已实现 | 原地之魔盘、两链/孔位/锁定/属性与候选预览确认；原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。 | Blastic.gd, BlasticPage.gd, BlasticView.gd, Actions.gd |
| 0217 | Window_BlasticEquip | 已实现 | 原地之魔盘、两链/孔位/锁定/属性与候选预览确认；原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。 | Blastic.gd, BlasticPage.gd, BlasticView.gd, Actions.gd |
| 0218 | Window_BlasticEquipDesc | 已实现 | 原地之魔盘、两链/孔位/锁定/属性与候选预览确认；原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。 | Blastic.gd, BlasticPage.gd, BlasticView.gd, Actions.gd |
| 0219 | Window_BlasticGroup | 已实现 | 原地之魔盘、两链/孔位/锁定/属性与候选预览确认；原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。 | Blastic.gd, BlasticPage.gd, BlasticView.gd, Actions.gd |
| 0220 | Window_BlasticTitle | 已实现 | 原地之魔盘、两链/孔位/锁定/属性与候选预览确认；原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。 | Blastic.gd, BlasticPage.gd, BlasticView.gd, Actions.gd |
| 0221 | Window_BlasticCrystal | 已实现 | 原地之魔盘、两链/孔位/锁定/属性与候选预览确认；原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。 | Blastic.gd, BlasticPage.gd, BlasticView.gd, Actions.gd |
| 0222 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0223 | ▼ 笔记相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0224 | ->Storage | 已实现 | 五笔记分类及锁定/条目/富文本说明；原空分类保持为空。 | NotePage.gd, NoteView.gd |
| 0225 | Window_NoteCommand | 已实现 | 五笔记分类及锁定/条目/富文本说明；原空分类保持为空。 | NotePage.gd, NoteView.gd |
| 0226 | Window_NoteSelect | 已实现 | 五笔记分类及锁定/条目/富文本说明；原空分类保持为空。 | NotePage.gd, NoteView.gd |
| 0227 | Window_NoteDesc | 已实现 | 五笔记分类及锁定/条目/富文本说明；原空分类保持为空。 | NotePage.gd, NoteView.gd |
| 0228 |  | 源空槽/注释 | 原源空槽/注释； |  |
| 0229 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0230 | ▼ 灵视系统 | 源空槽/注释 | 原源空槽/注释； |  |
| 0231 | Window_SightMap | 已实现 | 地图A四聚焦、敌人/物品、技能详情、行动顺序；BUFF源空钩子及手动轮播实际边界保留；0234废弃块注释不执行。 | SightModel.gd, SightPage.gd, SightView.gd, ActionOrder.gd, BattleSimulator.gd |
| 0232 | Window_SightDesc | 已实现 | 地图A四聚焦、敌人/物品、技能详情、行动顺序；BUFF源空钩子及手动轮播实际边界保留；0234废弃块注释不执行。 | SightModel.gd, SightPage.gd, SightView.gd, ActionOrder.gd, BattleSimulator.gd |
| 0233 | Window_Enemy | 已实现 | 地图A四聚焦、敌人/物品、技能详情、行动顺序；BUFF源空钩子及手动轮播实际边界保留；0234废弃块注释不执行。 | SightModel.gd, SightPage.gd, SightView.gd, ActionOrder.gd, BattleSimulator.gd |
| 0234 | Window_Enemy（废弃） | 源空槽/注释 | 原源空槽/注释； |  |
| 0235 | Window_EnemySkill | 已实现 | 地图A四聚焦、敌人/物品、技能详情、行动顺序；BUFF源空钩子及手动轮播实际边界保留；0234废弃块注释不执行。 | SightModel.gd, SightPage.gd, SightView.gd, ActionOrder.gd, BattleSimulator.gd |
| 0236 | Window_EnemyAction | 已实现 | 地图A四聚焦、敌人/物品、技能详情、行动顺序；BUFF源空钩子及手动轮播实际边界保留；0234废弃块注释不执行。 | SightModel.gd, SightPage.gd, SightView.gd, ActionOrder.gd, BattleSimulator.gd |
| 0237 | Window_EnmeyAction2 | 已实现 | 地图A四聚焦、敌人/物品、技能详情、行动顺序；BUFF源空钩子及手动轮播实际边界保留；0234废弃块注释不执行。 | SightModel.gd, SightPage.gd, SightView.gd, ActionOrder.gd, BattleSimulator.gd |
| 0238 | Window_SightHelp | 已实现 | 地图A四聚焦、敌人/物品、技能详情、行动顺序；BUFF源空钩子及手动轮播实际边界保留；0234废弃块注释不执行。 | SightModel.gd, SightPage.gd, SightView.gd, ActionOrder.gd, BattleSimulator.gd |
| 0239 | Window_EnemyList | 已实现 | 地图A四聚焦、敌人/物品、技能详情、行动顺序；BUFF源空钩子及手动轮播实际边界保留；0234废弃块注释不执行。 | SightModel.gd, SightPage.gd, SightView.gd, ActionOrder.gd, BattleSimulator.gd |
| 0240 | Window_ItemList | 已实现 | 地图A四聚焦、敌人/物品、技能详情、行动顺序；BUFF源空钩子及手动轮播实际边界保留；0234废弃块注释不执行。 | SightModel.gd, SightPage.gd, SightView.gd, ActionOrder.gd, BattleSimulator.gd |
| 0241 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0242 | ▼ 地图系统 | 源空槽/注释 | 原源空槽/注释； |  |
| 0243 |   —>地图右下显示 | 源空槽/注释 | 原源空槽/注释； |  |
| 0244 | Window_RD_Map | 源未完成 | 地图M→实际0248/0251发现、连接、区域及预览；旧右下地图窗口依赖已不存在的最终对象 | MapConfig.gd, MapSystem.gd, MapBlock.gd, MapCursor.gd, MapPreview.gd, MapScreen.gd |
| 0245 |   —>相关定义 | 已实现 | 地图M→实际0248/0251发现、连接、区域及预览；0244/0249/0250是旧未衔接半成品，不伪造已不存在的字段或Spriteset_MapSystem旧构造。 | MapConfig.gd, MapSystem.gd, MapBlock.gd, MapCursor.gd, MapPreview.gd, MapScreen.gd |
| 0246 | Game_MapSystem | 已实现 | 地图M→实际0248/0251发现、连接、区域及预览；0244/0249/0250是旧未衔接半成品，不伪造已不存在的字段或Spriteset_MapSystem旧构造。 | MapConfig.gd, MapSystem.gd, MapBlock.gd, MapCursor.gd, MapPreview.gd, MapScreen.gd |
| 0247 | Game_MapBlock | 已实现 | 地图M→实际0248/0251发现、连接、区域及预览；0244/0249/0250是旧未衔接半成品，不伪造已不存在的字段或Spriteset_MapSystem旧构造。 | MapConfig.gd, MapSystem.gd, MapBlock.gd, MapCursor.gd, MapPreview.gd, MapScreen.gd |
| 0248 | Window_Map | 已实现 | 地图M→实际0248/0251发现、连接、区域及预览；0244/0249/0250是旧未衔接半成品，不伪造已不存在的字段或Spriteset_MapSystem旧构造。 | MapConfig.gd, MapSystem.gd, MapBlock.gd, MapCursor.gd, MapPreview.gd, MapScreen.gd |
| 0249 | Window_Map_Selct | 源未完成 | 地图M→实际0248/0251发现、连接、区域及预览；旧地图选择窗口未接入最终0248/0251 | MapConfig.gd, MapSystem.gd, MapBlock.gd, MapCursor.gd, MapPreview.gd, MapScreen.gd |
| 0250 | Sprite_MapBlock | 源未完成 | 地图M→实际0248/0251发现、连接、区域及预览；旧地图块精灵使用已不存在的字段 | MapConfig.gd, MapSystem.gd, MapBlock.gd, MapCursor.gd, MapPreview.gd, MapScreen.gd |
| 0251 | Spriteset_MapSystem | 已实现 | 地图M→实际0248/0251发现、连接、区域及预览；0244/0249/0250是旧未衔接半成品，不伪造已不存在的字段或Spriteset_MapSystem旧构造。 | MapConfig.gd, MapSystem.gd, MapBlock.gd, MapCursor.gd, MapPreview.gd, MapScreen.gd |
| 0252 | —————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0253 | ★Scene_EnemyView | 源空槽/注释 | 原源空槽/注释； |  |
| 0254 | ★Scene_Flytofloor | 已实现 | Game.show_flash_scene或原事件$scene请求；事件302/303；0257旧技能页调用最终不存在的skill_can_use?/skill_effect，只接既有公共事件浏览业务；0262无外部创建且draw_item为空，源未完成。 | SceneRegistry.gd, SelectionPage.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, EquipmentView.gd, ShopScene.gd, ShopView.gd, DebugPage.gd, ItemEffects.gd |
| 0255 | ★Scene_CP | 已实现 | Game.show_flash_scene或原事件$scene请求；事件302/303；0257旧技能页调用最终不存在的skill_can_use?/skill_effect，只接既有公共事件浏览业务；0262无外部创建且draw_item为空，源未完成。 | SceneRegistry.gd, SelectionPage.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, EquipmentView.gd, ShopScene.gd, ShopView.gd, DebugPage.gd, ItemEffects.gd |
| 0256 | ▲Scene_Item | 已实现 | Game.show_flash_scene或原事件$scene请求；事件302/303；0257旧技能页调用最终不存在的skill_can_use?/skill_effect，只接既有公共事件浏览业务；0262无外部创建且draw_item为空，源未完成。 | SceneRegistry.gd, SelectionPage.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, EquipmentView.gd, ShopScene.gd, ShopView.gd, DebugPage.gd, ItemEffects.gd |
| 0257 | Scene_Skill | 源未完成 | Game.show_flash_scene或原事件$scene请求；事件302/303；旧结算调用在最终角色中不存在；保留受限兼容入口 | SceneRegistry.gd, SelectionPage.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, EquipmentView.gd, ShopScene.gd, ShopView.gd, DebugPage.gd, ItemEffects.gd |
| 0258 | ▲Scene_Equip | 已实现 | Game.show_flash_scene或原事件$scene请求；事件302/303；0257旧技能页调用最终不存在的skill_can_use?/skill_effect，只接既有公共事件浏览业务；0262无外部创建且draw_item为空，源未完成。 | SceneRegistry.gd, SelectionPage.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, EquipmentView.gd, ShopScene.gd, ShopView.gd, DebugPage.gd, ItemEffects.gd |
| 0259 | Scene_Shop_new | 已实现 | Game.show_flash_scene或原事件$scene请求；事件302/303；0257旧技能页调用最终不存在的skill_can_use?/skill_effect，只接既有公共事件浏览业务；0262无外部创建且draw_item为空，源未完成。 | SceneRegistry.gd, SelectionPage.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, EquipmentView.gd, ShopScene.gd, ShopView.gd, DebugPage.gd, ItemEffects.gd |
| 0260 | Scene_Debug | 已实现 | Game.show_flash_scene或原事件$scene请求；事件302/303；0257旧技能页调用最终不存在的skill_can_use?/skill_effect，只接既有公共事件浏览业务；0262无外部创建且draw_item为空，源未完成。 | SceneRegistry.gd, SelectionPage.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, EquipmentView.gd, ShopScene.gd, ShopView.gd, DebugPage.gd, ItemEffects.gd |
| 0261 | ■Enemy_Ready | 源空槽/注释 | 原源空槽/注释； |  |
| 0262 | ■●Window_EnemyDate | 源未完成 | Game.show_flash_scene或原事件$scene请求；事件302/303；无外部创建，draw_item为空 | SceneRegistry.gd, SelectionPage.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, EquipmentView.gd, ShopScene.gd, ShopView.gd, DebugPage.gd, ItemEffects.gd |
| 0263 | ★Item caculator | 已实现 | Game.show_flash_scene或原事件$scene请求；事件302/303；0257旧技能页调用最终不存在的skill_can_use?/skill_effect，只接既有公共事件浏览业务；0262无外部创建且draw_item为空，源未完成。 | SceneRegistry.gd, SelectionPage.gd, ItemPage.gd, CastingPage.gd, EquipmentPage.gd, EquipmentView.gd, ShopScene.gd, ShopView.gd, DebugPage.gd, ItemEffects.gd |
| 0264 | ■enemy property | 源空槽/注释 | 原源空槽/注释； |  |
| 0265 | ■Window_Version | 已实现 | Godot实际输入快照和标题版本；0267/0268/0269均为注释/废弃稿，不当作待实现功能。 | RuntimeVersion.gd, Keyboard.gd, TitleScreen.gd |
| 0266 | ■full kboard | 已实现 | Godot实际输入快照和标题版本；0267/0268/0269均为注释/废弃稿，不当作待实现功能。 | RuntimeVersion.gd, Keyboard.gd, TitleScreen.gd |
| 0267 | ■●Window_PlayerData | 源空槽/注释 | 原源空槽/注释； |  |
| 0268 | 第一版UI | 源空槽/注释 | 原源空槽/注释； |  |
| 0269 | ■sort item | 源空槽/注释 | 原源空槽/注释； |  |
| 0270 | ■GPRA_TextStream | 已实现 | UTF8文本流、Message及地图伤害表现； | TextStream.gd, MessageController.gd, MessageMemoryPage.gd, EnemyMapLabels.gd |
| 0271 | ■GPRA_Window_Message | 源空槽/注释 | 原源空槽/注释； |  |
| 0272 | 伤害显示 | 源空槽/注释 | 原源空槽/注释； |  |
| 0273 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0274 | ▼ 特殊BOSS战 | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0275 | ■Skill追加 | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0276 | ■RPG相关追加 | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0277 | ObservableBattler | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0278 | Scene_BossBattle 1 | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0279 | Scene_BossBattle 2 | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0280 | Scene_BossBattle 3 | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0281 | Scene_BossBattle 4 | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0282 | Game_BossBattle_Data | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0283 | ■■Temp_Battler | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0284 | Game_Boss_Battler | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0285 | Game_Boss_Actor | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0286 | Game_Boss_Enemy | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0287 | Game_Boss_Tactical | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0288 | Battle_Calculator | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0289 | Window_Boss_Command | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0290 | Window_BCDesc | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0291 | Window_BCHelp | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0292 | Window_BDetail | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0293 | Arrow_Base | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0294 | Arrow_Enemy | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0295 | Arrow_Actor | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0296 | Animation_Damage | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0297 | Sprite_Damage | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0298 |  | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0299 | Sprite_BossStatus | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0300 | Screen_BossBattle | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0301 | ●Sprite_AT_List | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0302 | ->Sprite_AT_Block | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0303 | Sprite_Sp_Character(弃) | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0304 | Sprite_Boss_Character | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0305 | Spriteset_BossBattle | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0306 | Battle_Manager | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0307 | 备忘录 | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0308 | ———————————— | 已排除 | 用户排除的特殊BOSS范围； |  |
| 0309 | ▼ 剧情相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0310 | Game_Engine | 已实现 | 真实演出请求、等待/取消、位图消散和保存恢复；静电、冻结及Crash音效在当前可导入索引中存在，文件名大小写按运行时索引别名解析；默认sptx蒙版原缺失，0.59使用单独标记的程序生成480×480分区图，原图优先；其他自定义缺图明确拒绝。0312帮助set_text/update原为空；不接任意Ruby回调。 | ScreenEffects.gd, EffectView.gd, BrokenScreen.gd, Unravel.gd, HelpMessage.gd, Utils.gd, Bitmap.gd |
| 0311 | 碎屏 | 已实现 | 真实演出请求、等待/取消、位图消散和保存恢复；静电、冻结及Crash音效在当前可导入索引中存在，文件名大小写按运行时索引别名解析；默认sptx蒙版原缺失，0.59使用单独标记的程序生成480×480分区图，原图优先；其他自定义缺图明确拒绝。0312帮助set_text/update原为空；不接任意Ruby回调。 | ScreenEffects.gd, EffectView.gd, BrokenScreen.gd, Unravel.gd, HelpMessage.gd, Utils.gd, Bitmap.gd |
| 0312 | 游戏帮助 | 源未完成 | 真实演出请求、等待/取消、位图消散和保存恢复；set_text与update原为空 | ScreenEffects.gd, EffectView.gd, BrokenScreen.gd, Unravel.gd, HelpMessage.gd, Utils.gd, Bitmap.gd |
| 0313 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0314 | ▼ 工具类 | 源空槽/注释 | 原源空槽/注释； |  |
| 0315 | Utils | 已实现 | 真实演出请求、等待/取消、位图消散和保存恢复；静电、冻结及Crash音效在当前可导入索引中存在，文件名大小写按运行时索引别名解析；默认sptx蒙版原缺失，0.59使用单独标记的程序生成480×480分区图，原图优先；其他自定义缺图明确拒绝。0312帮助set_text/update原为空；不接任意Ruby回调。 | ScreenEffects.gd, EffectView.gd, BrokenScreen.gd, Unravel.gd, HelpMessage.gd, Utils.gd, Bitmap.gd |
| 0316 | BackSpace | 源空槽/注释 | 原源空槽/注释； |  |
| 0317 | Actor_Init | 已实现 | 初始化/成长、原事件前记录和BackSpace撤回； | Game_ActorInit.gd, History.gd, MapSnapshot.gd, Gameplay.gd, Preferences.gd, AudioRuntime.gd, ScriptRuntime.gd |
| 0318 | Level_Up | 已实现 | 初始化/成长、原事件前记录和BackSpace撤回； | Game_ActorInit.gd, History.gd, MapSnapshot.gd, Gameplay.gd, Preferences.gd, AudioRuntime.gd, ScriptRuntime.gd |
| 0319 | New_Audio | 源空槽/注释 | 原源空槽/注释； |  |
| 0320 | BackSpace(撤回) | 已实现 | 初始化/成长、原事件前记录和BackSpace撤回； | Game_ActorInit.gd, History.gd, MapSnapshot.gd, Gameplay.gd, Preferences.gd, AudioRuntime.gd, ScriptRuntime.gd |
| 0321 | 玄鸟专用调试用功能 | 源空槽/注释 | 原源空槽/注释； |  |
| 0322 | 玄鸟的突发奇想 | 源空槽/注释 | 原源空槽/注释； |  |
| 0323 | Movie_Player | 已实现 | Godot视频工具play/pause/resume/resize/stop；源没有视频素材或事件调用；无原片播放验收，MCI/DLL由Godot替代。 | MoviePlayer.gd, Game.gd |
| 0324 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0325 | ▼ 剧情相关 | 源空槽/注释 | 原源空槽/注释； |  |
| 0326 | 开关变量注释 | 源空槽/注释 | 原源空槽/注释； |  |
| 0327 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0328 | ▼ Vendor  | 源空槽/注释 | 原源空槽/注释； |  |
| 0329 | 航拍 | 已实现 | 地图航拍、消散、四跟随者和调试计时；原0330.run_img写入未定义字段且缺图片编号，使用明确Game.unravel_picture；任意回调诊断拒绝。 | MapSnapshot.gd, ScreenEffects.gd, Unravel.gd, Followers.gd, Bitmap.gd, Utils.gd, ScriptSemantics.gd |
| 0330 | 行走图 | 已实现 | 地图航拍、消散、四跟随者和调试计时；原0330.run_img写入未定义字段且缺图片编号，使用明确Game.unravel_picture；任意回调诊断拒绝。 | MapSnapshot.gd, ScreenEffects.gd, Unravel.gd, Followers.gd, Bitmap.gd, Utils.gd, ScriptSemantics.gd |
| 0331 | 位图消逝 | 已实现 | 地图航拍、消散、四跟随者和调试计时；原0330.run_img写入未定义字段且缺图片编号，使用明确Game.unravel_picture；任意回调诊断拒绝。 | MapSnapshot.gd, ScreenEffects.gd, Unravel.gd, Followers.gd, Bitmap.gd, Utils.gd, ScriptSemantics.gd |
| 0332 | 跟随 | 已实现 | 地图航拍、消散、四跟随者和调试计时；原0330.run_img写入未定义字段且缺图片编号，使用明确Game.unravel_picture；任意回调诊断拒绝。 | MapSnapshot.gd, ScreenEffects.gd, Unravel.gd, Followers.gd, Bitmap.gd, Utils.gd, ScriptSemantics.gd |
| 0333 | 临时debug | 已实现 | 地图航拍、消散、四跟随者和调试计时；原0330.run_img写入未定义字段且缺图片编号，使用明确Game.unravel_picture；任意回调诊断拒绝。 | MapSnapshot.gd, ScreenEffects.gd, Unravel.gd, Followers.gd, Bitmap.gd, Utils.gd, ScriptSemantics.gd |
| 0334 | ———————————— | 源空槽/注释 | 原源空槽/注释； |  |
| 0335 | ▼ Main | 源空槽/注释 | 原源空槽/注释； |  |
| 0336 | BATTLE_TEST | 源空槽/注释 | 原源空槽/注释； |  |
| 0337 | Main | 已实现 | Godot入口→标题→新游戏/继续→地图；原生RM战斗测试排除；0338/0339的注释草稿不执行。 | Title.gd, Game.gd, Gameover.gd, RuntimeState.gd, RuntimeVersion.gd |
| 0338 | 战斗圆盘 | 源空槽/注释 | 原源空槽/注释； |  |
| 0339 | ●RGSSruby | 源空槽/注释 | 原源空槽/注释； |  |

## 源边界与缺素材

- host：不提供任意DLL调用或原生地址；已知用途由Godot服务替代。
- drawing：原进程地址、DLL、窗口助手替换为Godot；闭源模糊不声称逐像素相同；0026上层遮挡在0.58补齐。
- preferences：音乐实际切曲和成就奖励在原源为空；不新增。
- items：原无Deputy定义及部分exdata；不存在的数据明确拒绝，不伪造副手。
- battlers：原缺exdata及未实现魔法分类保留。
- battle：0075/0076旧战斗数据接口保留兼容；特殊BOSS与RM回合制战斗排除。
- base-windows：0115/0116/0119/0126后续被同名窗口重开；旧五槽装备改用最终六槽兼容业务；旧0134由最终Message实际入口替代。
- title：音乐切曲/奖励原为空；成就仅原固定样例。
- message：源40Hz编写时间通过边界换秒，表现只有一个控制时钟。
- interpreter：301/601—603及331—340原生回合制战斗指令按既有范围排除；旧Scene_Menu的有效菜单职责由最终地图菜单承担。
- archive：不读RM Marshal旧档；图结构校验后才恢复。
- hud：BUFF显示空区按原样保留；0196废弃实现不作为最终入口。
- map-coordination：装备/成就/合成主菜单最终分支为空，不新增业务。
- skill-ui：魔法分类原未实现；0206旧窗口未在最终地图创建。
- orbment：原缺部分圆盘预设；0220标题refresh为空，回响描述硬编码减少0%保留。
- notes：原空分类保持为空。
- sight：BUFF源空钩子及手动轮播实际边界保留；0234废弃块注释不执行。
- map-system：0244/0249/0250是旧未衔接半成品，不伪造已不存在的字段或Spriteset_MapSystem旧构造。
- standalone：0257旧技能页调用最终不存在的skill_can_use?/skill_effect，只接既有公共事件浏览业务；0262无外部创建且draw_item为空，源未完成。
- version-keyboard：0267/0268/0269均为注释/废弃稿，不当作待实现功能。
- effects：静电、冻结及Crash音效在当前可导入索引中存在，文件名大小写按运行时索引别名解析；默认sptx蒙版原缺失，0.59使用单独标记的程序生成480×480分区图，原图优先；其他自定义缺图明确拒绝。0312帮助set_text/update原为空；不接任意Ruby回调。
- movie：源没有视频素材或事件调用；无原片播放验收，MCI/DLL由Godot替代。
- vendor：原0330.run_img写入未定义字段且缺图片编号，使用明确Game.unravel_picture；任意回调诊断拒绝。
- boot：原生RM战斗测试排除；0338/0339的注释草稿不执行。
- Audio/SE/静电声2：available_asset。缺失时原演出入口明确拒绝；不会伪造音效。
- Audio/SE/静电声：available_asset。缺失时原演出入口明确拒绝；不会伪造音效。
- Audio/SE/m魔法-爆气-重-005：available_asset。缺失时原演出入口明确拒绝；不会伪造音效。
- Audio/SE/crash：available_asset。缺失时原演出入口明确拒绝；不会伪造音效。
- Graphics/Pictures/sptx：missing_asset。原图缺失时使用有来源记录的0.59程序生成分区图；其他自定义缺图拒绝。

## 开发与验收入口

生成工程data/migration_audit.json保留逐方法声明、原行号、覆盖链、alias捕获、服务路径及测试组。脚本工作区分别展示职责审计与编译器诊断，不把自动转换unsupported当作已迁移服务缺失。新增来源或目标哈希变化须重新审计，正式导出会核对来源与目标内容。

原生事件正文仍在事件编辑器编辑保存；原Ruby只读。普通战斗/开门/拾取、消息/历史、菜单/功能页、存读档/撤回及编辑器自查见[0.59验证](../tests/VERIFICATION_v0.59.md)。完整剧情人工通关、原RGSS逐像素比对、无原片的视频播放及所有地图长期60FPS未由本报告证明。
