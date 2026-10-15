# 0.45 闪翼物品、装备对象与地图道具核对

2026-10-12。对应计划45-02、45-08的方法级记录。来源是闪翼实际加载的`Data/Scripts.rxdata`，下列加载序号与只读`legacy/ordered_scripts`副本一致；没有执行Ruby。本文的内部测试结果不代表0.45已正式导出，也不代表0.46页面或0.47对象关系存档已完成。

## 对象源码对应关系

生成工程使用`res://runtime/scripts/FlashObjectCatalog.gd`。迁移器中的可编辑模板是[FlashObjectCatalog.gd](../templates/runtime/scripts/FlashObjectCatalog.gd)，有限类型构造、字段读取和父类判断在这里集中维护；`CustomDataState.named/invoke`将原类名路由到该接口，`ScriptSemantics`使用同一个脚本事务。

| 原加载序号、方法/字段 | GDScript或数据入口 | 本版行为与证据 |
| --- | --- | --- |
| 0053 `Game_Object#initialize` L19、`load_default` L36、`load_data` L45 | `CustomDataImporter::_external_data` → `data/database/*._custom_data.external.settings`；`FlashObjectCatalog::construct/value` | 固定外部文件在迁移时读取、解析成数据及已生成表达式；运行时不执行原文件中的Ruby。默认空名/零价格/空描述/setting在读取缺块数据前建立，源缺块初始化错误按下方记录修正。通用任意文件构造/运行时重新解析字符串不冒充完成，归47-07。 |
| 0053 `id/name/price/setting` readers | `FlashObjectCatalog::value` | 分离外部名称/价格/描述和setting；setting中不重复保留构造器字段。定义数据只读，返回Array/Dictionary副本。原源码没有发现业务读写`.setting`；独立对象身份、可变setting的共享关系与存档归47-02。 |
| 0054 `Game_Item#initialize` L15；`icon_name/occasion/scope/animation1_id/animation2_id/description/common_event_id/consumable` L25—95 | `construct("Game_Item", [id])`、`value("Items", id, field)` | 外部名称拆出`<类别>`；原getter的外部设置→RPG数据库→rescue默认值路径；Ruby中零是有效覆盖，nil/false走`||`回退；描述保留首空行并删去无limit的Ruby split不保留的末空行。原Item1实际四行描述经共享事务访问验证。 |
| 0055 `Game_Weapon#initialize` L15、`class_set`；所有getter L33—115及`agi/int` alias | `construct("Game_Weapon", [id])`、`value("Weapons", id, field)` | 可装备职业优先外部class_set，否则按原Classes.weapon_set；原patk→atk、matk→pdef回退；速度/个性别名；抗性不补造分量，原Weapons.exdata的三分量示例仍保留。 |
| 0056 `Game_Armor#initialize` L11、`class_set`；所有getter L29—112及`hp_plus/agi/int` alias | `construct("Game_Armor", [id])`、`value("Armors", id, field)` | kind/图标/描述、防御和速度/个性回退；hp/hp_plus默认零；职业取Classes.armor_set。class_set显式提供已提取数据的访问，不额外给源Actor.equip加入原来没有的校验/背包交换。 |
| 0057 `Game_Ornament#initialize` L11；所有getter L24—107及alias | `construct("Game_Ornament", [id])`、`value("Ornaments", id, field)` | 饰品从外部设置读取，缺失值按原零/空图标/五个零抗性，不将原RPG防具数值当作饰品数值；类型父类为Game_Object。 |
| 0086 `Game_Equipment#[]` L20 | `FlashObjectCatalog::equipment_ref`；`ScriptSemantics::indexes_get` | 两个下标组成有限分派：0武器、1副手、2上下装、3饰品。原id>999返回nil；id0仍可取得默认对象。缺少Game_Deputy及Deputy.exdata明确失败，未采用Deputies.txt示例替代。逻辑引用不等于原对象缓存身份已完成，后者归47-02。 |
| 0078 `item_can_use?` L273、`in_map_use?` L293 | `CustomDataState::party_call`；`FlashActions::recover_item/request_tool` | 保持源背包数量、原occasion与in_battle限制；恢复品与工具公共事件入口由业务事务接入，证据见`FlashBusinessTests.gd`。 |
| 0068 `equip` L163；0069所有base属性getter | `FlashActorState::equip_project/_project_base_parameter/get_resist` | 六槽分别使用Weapon/Deputy/Armor/Armor/Ornament/Ornament。源拼写euqipment修正；源pdef取patk点数、mdef取matk点数及base_resist未累计装备返回值保留。测试见玩法与Battler记录，不把Catalog getter检查当作角色公式检查。 |

直接GDScript开发可调用`FlashObjectCatalog.construct(custom, "Game_Weapon", [id])`或`equipment_ref(custom, kind, id)`；原Ruby类名的已迁移调用由`ScriptRuntime.new_object`路由至相同接口。`class_name_for/is_a`提供明确类型与`Game_Object/Object`父类判断。原`Game_Object.new(key,id,filename,path)`没有任意文件执行入口，调用会得到明确未支持诊断。

## 地图道具源码对应关系

生成工程使用`res://runtime/scripts/FlashItemEffects.gd`，可编辑模板为[FlashItemEffects.gd](../templates/runtime/scripts/FlashItemEffects.gd)。公开业务入口是`FlashActions.use_item`，原`Storage`对象与原事件也经过`ScriptRuntime`和同一CustomData事务。

| 原加载序号、方法 | GDScript或生成方法 | 本版保持的行为 |
| --- | --- | --- |
| 0052 `use_item` L15 | `FlashItemEffects::invoke` | 默认Game_Temp.item_id；原工具顺序、药水表先于宝石表（实际ID重合不重排）、解状态分派；未知ID返回false。 |
| 0052 `pickaxe` L63、`ice_pickaxe` L124、`freeze` L159 | `FlashItemEffects::_map_effect`、`FlashMapBridge::read_tile/write_tile` | 面前暗墙/暗冰/暗熔B/b保护；原图块编号/层/Range匹配；成功图块处理覆盖先前事件失败标志；失败不扣物品。图块变化与只读地图定义分开保存。 |
| 0052 `quake` L98 | `_map_effect` | 按源map_range逐格移除暗墙与墙图块，范围外不变；没有目标也按原逻辑消费成功。 |
| 0052 `symcraft` L194 | `_map_effect`、`FlashMapBridge::passable_zero`、`FlashCharacterBridge::commit` | 原中心对称位置计算及方向0的原可通行语义，成功后移动同一原生玩家并扣物品。Storage错误字段归属按下方记录修正。 |
| 0052 `giant_key` L213、0091 `open_door_list` L49 | `_map_effect`；`ScriptMigrationInventory::_flash_door_macro`；`runtime/generated/derived_0091_door_die.gd` | 源map_range的x/y顺序，每格只取check_event返回的首个事件；匹配`^门0*1`后安装页list并refresh。宏从原CE4动画标签提取副本、归一化indent、保留原CE5/强制转向/等待并绑定原尾部`_this.die`。安装保持原页trigger，不自行发明即刻自动播放。消费只发生于Storage调用，执行宏不重复扣黄钥匙。 |
| 0052 `bomb` L234、`strike` L261 | `_map_effect` | 炸弹面前、圣锤四邻的普通怪物死亡标记；B/b怪物不被杀死；无有效目标保留物品；圣锤误扣炸弹修正。 |
| 0052 `potion` L288、`gem` L305 | `invoke`、`FlashActorState::set_project_parameter/set_resist` | Storage药水增加MAXHP，区别于CE2当前HP加减；原宝石数值/数组类型直接计算；源没有的宝石ID映射明确失败并回滚；死亡预约原CE12。 |
| 0052 `poison/weak/slow/curse` L324—360、`slear` L372 | `invoke` | 单项药水仅对应状态存在时消费，万能药移除四种状态并调用源战斗不能恢复，成功消费一次。 |
| 0052 `upper/lower/craft/will_gate/sword` L390—414 | `invoke` | 原方法仅含“待完成”注释。保持nil、无扣物品、无换图或自创效果，单列原未设计分支。 |
| 0193 `Item.Recover` L9 | `runtime/generated/script_0193.gd` | 原单体回血/SP与恢复战斗不能、扣物品、人物动画、refresh_damage；保留`maxhp * recover_hp_rate + recover_hp`和SP对应公式，未增加/100。由原绑定检查及业务入口检查验证。 |
| 0263 `Item_calc#initialize/cal_item` L14/L22 | `runtime/generated/script_0263.gd` | 原类别1/2/3图标名→行走图名、方向、pattern算法；原源事件检查已覆盖实际生成方法。 |

0091中的`door_event/set_blank_page`没有发现普通事件或其他库的实际调用；`damage_color`被0099 Sprite_Character显示读取，归0.46演出。这里只完成巨钥匙实际使用的`open_door_list`，不能将0091整文件声明完成。

## 源错误修正与保留项

- 0053 `initialize`：外部文件存在但缺少ID块时，原`load_data`在L49提前返回，名称/价格/描述没有初值，Game_Item随后的名称正则会对nil调用。目标先使用原`load_default`的默认值；固定源数据处理保留，通用文件执行不引入。该修正登记到`data/source_corrections.json`。
- 0052 `use_item`的默认值少`$`、巨钥匙`set_map_page`误名、圣锤误扣`BOMB_ITEM_ID`、symcraft取错Storage.@map_center归属，以及宝石数组字符串插值结构丢失，都由迁移副本修正并登记。symcraft仅取原0043中已有system.map_center，公式仍为中心×2−当前位置。
- 0091提取门宏时在标签前提前return、直接修改原指令indent的错误已修正为跳过标签前内容并操作副本；尾部仍来自原代码中的`_this.die`，生成绑定不会计入144个原片段的数量。
- 不调整原药水MAXHP、Item.Recover倍率、药水/宝石冲突优先级、装备攻击/防御/抗性公式；源缺少副手实现只给出诊断；源五个空工具不扩展玩法。

## 行为验证

独立检查基于原工程导入的JSON、原Map010/公共事件及实际Flash资产，测试中的人为输入单列在代码注释中。没有用编译/生成数量证明业务完成。

| 检查脚本 | 结果 | 主要证据 |
| --- | --- | --- |
| [FlashObjectTests.gd](../tests/runtime/FlashObjectTests.gd) | 22项通过 | 原四类构造通过共享事务、实际Item1描述、getter/alias/外部与数据库回退、零和false语义、缺记录默认、职业集合、饰品独立类型、ID0/上限、副手缺口。部分getter数据使用合成输入逐一分离公式。 |
| [FlashStorageDispatchTests.gd](../tests/runtime/FlashStorageDispatchTests.gd) | 20项通过 | 默认临时item_id、真实ID冲突顺序、四种解状态无状态/成功分支、万能恢复、五种原空分支、无映射宝石回滚、原Storage不分派普通恢复品、冰镐B保护与图块成功优先。 |
| [FlashGiantKeyFlowTests.gd](../tests/runtime/FlashGiantKeyFlowTests.gd) | 8项通过 | 原Map010黄色门56/蓝色门57及原宏完整走过CE5、原生强制转向路线、等待、生成尾部永久死亡；原定义只读、不重复扣普通钥匙、重叠事件只取首个。测试加速原生时钟，没有另写开门效果。 |
| [FlashMapItemTests.gd](../tests/runtime/FlashMapItemTests.gd) | 原12项回归通过 | 墙/地震/岩浆Range/对称飞行/炸弹B保护/圣锤/巨钥匙绑定、独立图块覆盖与存档坐标校验。该脚本使用合成地图条件，完整巨钥匙流程由上一项补证。 |

上述62项只覆盖本表对象/地图道具接口与直接依赖。角色数值、怪物战斗、普通公共事件全流程及场景业务另有对应检查；图形页面和完整共享/循环对象存档仍须按0.46/0.47完成。

## 场景选择与商店业务补核

0254/0117的选择/取消对应FlashActions.choose_floor/cancel_floor，保留变量13楼层或stop；0255/0118对应choose_character/cancel_character，保留变量12的actor.id-1或实际主战ID。原目标窗口未被激活，选择服务不发明传送/换角。0259交易对应ShopService的Flash事务分派，保留只买/只卖限制、数量上限、原价格和整数半价（原价1可售得0、原价0不可售）、gain_gold原封顶。源缺失的武器/防具背包调用使用既有共享typed inventory并登记修正；道具保留gain/lose_item的提示及手册刷新。FlashSceneShopBusinessTests的29项通过，包括刷新失败后扣款/背包/提示/缓存/通知整体回滚及Native对照。公开RuntimeState.use_item已分派源0193恢复及CE9工具预约，FlashBusiness的25项含公开入口公式和消耗检查。页面接入仍归0.46。
