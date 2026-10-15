# 0.40 脚本盘点与最小转换链

2026-10-11。对应0.4计划的第一个小版本，目标是建立可追溯输入和可运行的最小链。完整Ruby语法、全工程语义转换、魔塔玩法和事件自动入口按0.41—0.49继续实施。

## 本版产物

正式迁移两份原RM工程到 `../output/0.40/first-reviewed/`，历史输出和本轮早期 `first/` 保留。每个新工程包含：

| 文件 | 内容 |
| --- | --- |
| `legacy/ordered_scripts/` 或 `legacy/ruby_scripts/` | 从Scripts.rxdata按原顺序提取的完整Ruby；展开镜像另行原样保留 |
| `data/script_inventory.json` | 原脚本ID/名称/加载顺序；所有原事件脚本位置；定义版本、alias声明、调用候选、全局对象和功能词证据；镜像差异 |
| `script_inventory.md` | 加载顺序、事件入口、转换状态、首个诊断、功能追溯入口 |
| `data/script_units.json` | 每个单元的来源、严格子集解析/生成状态、诊断；成功单元的AST/IR与生成路径 |
| `runtime/generated/*.gd` | 迁移时生成的纯GDScript，不执行Ruby，不要求外部运行时 |

盘点在EditorScriptAdapter将Ruby变成占位之前读取原数据。355/655片段保留每条原指令编号，并提供Ruby行到原指令的映射；111条件、强制路线45和自主路线45保留独立来源。原生Troops战斗页仍不执行，其数据保持；工程的楼层怪物Game_Troop不按名称排除。

原工程解释器均合并连续355/655，所以按完整合并片段转换，不能从较大片段截取一条可支持的赋值宣称完成。闪翼的Interpreter 7（加载顺序165，第254行）使用 `eval(script, __UBIND)`，执行后返回true；二律背反的Interpreter 7（顺序86，第254行）在结果为false时返回false。盘点记录这两种上下文/返回行为；等待和恢复接入留在0.43。

## 最小编译范围与格式

0.40接受以下完整程序，支持换行、分号和普通行注释：

```ruby
$game_variables[7] = 3
$game_variables[7] += 2
$game_variables[7] -= 1
$game_switches[4] = true
```

下标是1..2147483647的十进制整数常量；变量值绝对值不超过2147483647。前导零、浮点、动态下标、普通表达式、调用、条件、类/方法定义和其他结构明确拒绝。错误返回原脚本名称/ID/顺序或地图/事件/页/公共事件/指令位置，以及1起始的行列；列按Unicode字符计数。整段有任意不支持内容，IR与生成源码均为空，不产生可运行的半段代码。

AST的program节点包含origin及statements；indexed_assignment保存target、id、operator、value、span。IR为state_write，保留同一span；0.41扩展时在这一结构上添加完整表达式/语句节点。词法依赖盘点不冒充完整AST：目前不解析正则/heredoc/插值的全部结构、不绑定接收者作用域，也不推断可达性。中文全局变量、大小写精确名称、常见操作符方法及每次重定义/alias声明保留为候选证据；不会将同名方法合并成最终实现。

生成函数调用ScriptStateBridge，先验证全部操作、原值和计算范围，再通过既有RuntimeState.set_event_variable/set_event_switch提交。原生事件条件、界面通知和SaveCodec使用同一份状态。运行时不每帧解析源码。ScriptRuntime.execute_unit提供显式验证调用；本版不自动执行脚本列表，不恢复事件占位，编辑器不执行Ruby。

## RM-sync评估与移植边界

已只读核对 `D:\Dev\CS\RM-sync\Rm-sync\Editor` 下的四个参考文件，没有启动或修改参考工程，也没有引入.NET。

| 参考能力 | 本版决定 | 后续缺口 |
| --- | --- | --- |
| RubyAstService的作用域树、声明和签名扫描 | 参考声明/符号/位置的组织；采用纯GDScript词法证据索引，另外实现严格子集AST | ParseDocument主要建立作用域/符号；完整表达式树、运算优先级、块与异常路径在0.41补齐 |
| RubySemanticIndex的跨文件定义/引用查询 | 输出原位置和候选定义；保存每次定义版本，不声称已完成绑定 | 调用接收者、隐式self、继承、类重开、alias捕获旧实现和覆盖順序在0.42实现 |
| 参考代码的OrdinalIgnoreCase集合与同名方法替换 | 编译索引改为大小写精确；定义/alias按原加载顺序追加 | 不直接复制忽略大小写或只保留最后定义的行为 |
| DocumentAnalysis的版本快照、延迟分析和缓存 | 迁移时一次分析/生成，运行时读取缓存结果；保留源码哈希 | 0.48实现编辑后的增量重转换与过期结果淘汰 |
| RgssApiCatalog和RubyAstService内置签名 | 作为接口盘点参考，执行仍走本项目现有RuntimeState/服务 | 签名存在不代表Godot功能已接通；自定义接口按实际工程核对 |
| C#字符索引与容错闭合作用域 | GDScript以Unicode字符记录行列；严格子集输入失败即不生成 | 完整AST需另行处理UTF-8字节位置、heredoc、正则/插值和不完整源码 |

本版没有运行RM-sync分析器，也没有宣称复用其完整编译能力。采用其静态分析设计作为参考，转译器继续用独立严格节点与诊断扩展；0.41无需玩家安装Ruby或C#运行时。

## 关键玩法的追溯入口

以下是源码和原事件证据，不是功能完成清单。完整逐项位置在各工程盘点中，动态调用和同名覆盖仍需语义验证。

| 工程 / 功能 | 入口与依赖 | 后续阶段 |
| --- | --- | --- |
| 闪翼：魔塔战斗与奖励 | 公共事件1“战斗”，开头读取_this.enemy.pending_battle_result，后续finish_battle、gain_exp/gain_gold；脚本72 BattleSystem的Simulator.run、StateContainer.physical_damage、PartyRoles主战/援护 | 0.42上下文，0.45公式和结算 |
| 闪翼：额外货币 | 脚本78 Game_Party.gain_currency第151行，字符串eval选择gain_gold/gain_kin | 0.44货币，0.45交易 |
| 闪翼：自定义物品/装备属性 | 脚本53 Game_Object.load_data第45行，从文本标签解析属性并eval集合/公式 | 0.44自定义数据，0.47剩余动态表达式 |
| 闪翼：楼层怪物及地图技能 | 脚本79 Game_Troop.load_enemies读取地图事件名“怪物ID”，Game_Troops按地图保存排列；Enemy_Ready、map_range及地图伤害刷新 | 0.44楼层排列，0.46地图行为 |
| 闪翼：菜单、对话与HUD | Window/Scene脚本、Message/TextBox/HintBox及Message_Controller；有6处展开镜像与rxdata不同，两份分别保存词法证据 | 0.46界面；源码选择不能静默决定 |
| 二律：战斗、伤害预测和奖励 | 公共事件1“战斗”创建Enemy_property并读got_damage/got_list；脚本125、135等重开Enemy_property，脚本132战斗缓存freeze_actor；公共事件2调用get_damage_before_battle | 0.42覆盖版本，0.45公式/缓存 |
| 二律：楼层、属性成长和装备状态 | 公共事件7上下楼、23楼层怪物判断、26升级、56/57装备存储加载；$floorenemies、中文全局对象、变量数组及Actor/Buff接口 | 0.44数据，0.45效果，0.47存档 |
| 二律：物品与快捷键 | 公共事件6快捷键、9使用物品；自定义物品合成及自动拾取脚本，读取/修改Game_Party背包与角色Buff | 0.43入口，0.45物品效果 |
| 两工程：显示/本机插件与存档 | Win32API、Bitmap/航拍脚本、Window/Scene和保存读取代码；调用证据按原顺序保留 | 0.46显示，0.47等价适配与存档 |

原生回合制战斗/战斗事件不在范围；上述工程自定义魔塔结算、楼层怪物排列和数据库扩展仍在0.4范围。未转换单元保持源码，不生成空函数或默认真条件。

## 事件竖线

EditorCommandList从条件/选择/循环的完整span绘制外层结构线，贯穿每个内部行及对应结束；具体指令按indent逐层内缩，文章/注释条仅贯穿自身续行。正文仍按首句标签宽度对齐，点击任意续行仍选择整条指令。真实插件检查嵌套条件/否则/循环、多行文本和滚动后的末尾，详见验证记录。
