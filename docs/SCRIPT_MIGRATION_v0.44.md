# 0.44 自定义数据与属性

本版按原0.4计划迁移数据层。原Ruby只读解析，不运行Ruby，也不依赖.NET。0.45继续战斗、成长和物品/技能/装备效果；0.46继续窗口、立绘和地图表现；0.47完成插件及复杂对象关系存档。用户的整体验收仍在脚本功能完成后进行。

## 本版能力与边界

- 原Scripts.rxdata加载顺序仍为依据。二律背反的Monster.Load、equipLoad、itemLoad中的可确定赋值按真实调用顺序导入；同一ID后面的赋值覆盖前面的赋值。原ID、名称标签及引用保持。技能的txt说明读取原Info/Skill文件。其他Info文件和非rxdata的Data文件按原字节保留。
- 闪翼的exdata按Global中的真实文件名读取；设置原文、生成表达式、来源行和字面值保留。Ruby只有false/nil是假；源码用`setting || base`的访问器按这个规则生成实际字段，0和空集合不触发回退。
- 金币按源工程上限增减。闪翼增加KIN、五类耀晶石与hatred字段；`gain_currency(type,n)`、`gain_spar(n,type)`保持原参数顺序。二律背反的36位金币上限使用精确十进制运算。原生125、金币条件、商店和菜单共用余额。
- 角色已确定的原始扩展字段（如tp_plus、hprate、equip_id、resist_plus）按角色ID持有，在脚本与菜单扩展属性页读取同一状态；初始值在数据库的“扩展属性”页编辑。Actor_Init预设已提取到项目数据；应用预设和完整派生属性公式按0.45接入。旧原生参数页不能当作完整自定义战斗状态的验收依据。
- 闪翼Game_Troop按楼层怪物排列处理。以原事件名称、编号及包含端点的map_range建立坐标/事件双索引；支持查询、实例字段修改、清空、加载、随实际事件位置更新，移除的事件不再返回。原生回合制Troops仍只保留查看。楼层缓存不执行未迁移的Game_Enemy伤害构造流程。原enemy_event访问器用坐标数组去查按事件ID存储的Game_Map.events；本版数据适配器按传入的事件ID检查实际事件，修正该查询问题，仍返回原来的[坐标,怪物]形状。
- 脚本变量支持标量、Array及Ruby Hash；嵌套修改和数据库实例覆盖随整段脚本提交，后续出错时回滚。数值事件遇集合明确失败，不把集合转成0。只读原始数据库与运行时记录覆盖分开。
- 普通树形自定义数据、货币、变量集合和楼层实例加入当前存档；读档整体校验后恢复，新游戏重置。循环、共享引用及自定义类对象仍明确拒绝保存，完整对象图按0.47实现。
- 地图与公共事件原注释分组保留来源和哈希；数据引用标签和名称标签保留原文。标签的玩法效果按0.45，立绘标签的显示行为按0.46；未接入的立绘指令执行时明确报错。

## 原Ruby对应的GDScript结构

生成工程中的源码和数据位于以下位置，迁移器内对应模板为templates/runtime/scripts。

| 原实现 | 对应文件/数据 | 开发入口 |
| --- | --- | --- |
| Global / Kernel数据常量、初始全局数组 | data/custom_data.json；ScriptRuntime.gd | manifest.constants/globals按源初始化；已确认数据与未初始化数据分开 |
| Game_Object / 外部exdata读取 | CustomDataImporter.gd；data/database/*.json；data/custom_units.json | 迁移时读取、解析与生成；可分析表达式进入runtime/generated/data_*.gd |
| Monster.Load / equipLoad / itemLoad | CustomDataImporter.gd；数据库字段的_custom_data来源 | 启动数据导入；动态Monster.set/eset由CustomDataState.monster_set适配；其他Monster玩法方法仍按覆盖状态处理 |
| Game_Party货币 | DecimalInteger.gd；CustomDataState.gd；RuntimeState.gd | gain_currency；currency/currency_maximum/currency_rows |
| Game_Actor原始扩展属性 | CustomDataState.actor_attributes；Actors._custom_data.attributes | RuntimeState.custom_actor_attributes返回展示快照；脚本写入经事务提交 |
| DataBase楼层树 | data/custom_data.json中的floors；CustomDataState.gd | 地区/楼层ID及P等模板关系；get_floor_type |
| Game_Troops / Game_Troop排列 | CustomDataState.gd | $game_troops[map_id]，enemies双索引、enemy_check、enemy_event、clear_enemies、load_enemies、update |
| 可变$data_*实例字段 | RuntimeState.custom_data.values.records；RuntimeData.record | source_record为只读定义，record为含现场覆盖的视图；custom_record返回脱离现场快照 |
| 脚本事务和持久化 | ScriptSemantics.gd；SaveCodec.gd；SaveService.gd | 完整校验后commit_script_data，一次公布状态；普通数据恢复，复杂对象图暂不保存 |

例如，闪翼脚本`$game_actors[2].tp_plus["patk"] = 37`修改2号角色的原始物攻修正字段；`$game_party.gain_currency(1,50)`增加50 KIN，`gain_spar(17,3)`增加第3类耀晶石17。这几项写入后，菜单读取同一运行状态，存读档保留；不会把它们写回数据库初始定义。物攻最终计算和装备/状态倍率在0.45完成。

二律背反802号敌人在Monster.Load前面设置HP为420000000，后面再次设置为50000000，最终采用50000000；独立的maxsp=20000仍保留。150号武器的str_plus和dex_plus均为10000000000，不截成32位。227号武器的冒号名称和原始标签完整保留，标签战斗效果待0.45。

## 编辑方式

数据库的常规数值和名称仍在原专用页编辑，已经导入的字段不出现第二份可编辑入口。角色增加“扩展属性”；原文、来源和未分析设置在“自定义数据来源”只读查看。数据库列表按实际数据增加“项目自定义数据”和“自定义饰品”；项目页编辑货币名称/上限、系统默认值、角色预设、楼层关系和初始全局数据。货币标识被脚本引用，不允许任意增删/改名。

这些入口操作脱离游戏现场的草稿，Ctrl+S才保存。源表达式的修改与重新转换按0.48接入；本版可查看其原文、来源和生成文件，不把改写Ruby原文当作已重新编译。

闪翼Global配置的是Enemy.exdata、Deputy.exdata，而原目录只有Enemies.txt、Deputies.txt示例。按原名报告缺失，保留示例，不能擅自用示例替代实际配置。数据可导入不表示整个原脚本库或玩法已完成；具体适配方法和未确定项见custom_data_inventory.md及data/custom_data.json。

## 检查与输出

针对加载顺序、大数、false回退、原ID、范围端点、生成表达式、嵌套集合事务、菜单/编辑器入口、存档与重置进行了检查；实际记录见tests/VERIFICATION_v0.44.md。正式工程从两个原始RM工程重新运行Validator与MigrationPipeline生成，最终目录为../output/0.44/release/。历史输出保留。

2026-10-12按用户要求追加的[闪翼0.43—0.44既有实现清单](FLASH_SCRIPT_CHECKLIST_v0.43_v0.44.md)逐项列出原脚本、实际暴露字段、服务方法、生成与事件绑定状态。回溯核对确认POTION_ITEM_ID/GEM_ITEM_ID后续逐项赋值未导入，0.44产物仍为空Hash，纳入45-01补迁；仅提取初始化不等于完整数据/方法迁移。
