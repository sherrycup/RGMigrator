# 0.41 / 0.42 脚本解析、语义转换与状态桥接

按原0.4计划顺序实施。用户2026-10-11明确不前移功能验收或脚本工作区交付；0.43接入事件，0.44—0.47补齐项目功能，0.48提供脚本工作区，0.49整合验收。本阶段仍区分解析、生成、显式执行、自动接入和玩法验证。

## 0.41：AST

RubyLexer/RubyParser以纯GDScript处理表达式优先级、赋值、条件/修饰条件、while/until/for、方法与参数、类/模块、alias、数组/Hash、字符串及插值、范围、case、块、begin/rescue/else/ensure。节点保留1起始Unicode行列；插值内部位置映射回原文。大整数保留原文本，不尝试溢出转换。块不闭合、无效赋值目标、未知结构和无法处理的转义均诊断，不容错生成。

不是完整Ruby语言实现。heredoc、复杂命令调用歧义、特殊全局变量、若干数字/转义格式、动态单例类、未支持关键字等保留原文并定位。正则形成节点，但不作为已完成语义的生成结果。0.41的执行能力保持0.40常量赋值子集，不因为AST成功而扩大自动运行范围。

## RM-sync参考

只读参考用户提供的D:/Dev/CS/RM-sync/Rm-sync/Editor/RubyAstService.cs、RubySemanticIndex.cs、DocumentAnalysis.cs、RgssApiCatalog.cs。采用其作用域/符号/参数/集合类型与快照分层设计；扩展为完整语句/表达式节点。标识符严格区分大小写，保留全部定义版本，alias捕获定义时可见版本；没有复制其忽略大小写或最后定义覆盖历史的索引规则。没有运行或修改该编辑器，没有引入.NET/Ruby运行时。

Ruby 1.8运算优先级另核对[官方旧版parse.y](https://github.com/ruby/ruby/blob/ruby_1_8_7/parse.y)，例如and/or同优先级、幂高于一元负号。现代Ruby规则不直接替代旧版语义。

## 0.42：生成与运行

RubyGDScriptCompiler将已支持节点生成为直接执行的GDScript函数、条件和循环。运行时ScriptSemantics只提供语义/分派/状态适配，不逐帧解析Ruby，也不解释AST/IR。表达式失败先退出，再整体回滚。

- 真值只把nil和false视为假；短路表达式返回原操作数且只计算必要分支。
- 32位精确范围内整数及有限浮点运算；整数负除法向下取整，模数与之配套。溢出/除零拒绝。Ruby任意精度大整数尚未生成。
- 局部/实例/全局/常量作用域、方法显式及隐式返回、默认和rest参数、继承、类重开、方法覆盖、声明时alias、直接include/extend、attr成员及自定义下标方法。
- 数组负下标、越界nil及扩展写入、Hash基本类型键；Symbol与String键不混淆。each/map/times/each_with_index块捕获已有局部变量；Array迭代读取实际集合的当前值；回滚保留集合的共享引用关系。
- Ruby 1.8数组字符串转换采用连接语义。字符串插值有原位置；旧Ruby字节下标和非ASCII字节长度明确拒绝，避免误用Godot Unicode字符规则。
- $game_variables/$game_switches直接桥接现有RuntimeState；$game_party.gold/gain_gold/lose_gold沿用原生金币范围和通知。写入先暂存，成功统一提交；原生条件、菜单和存档读取同一状态。其余游戏对象/API逐项诊断，不建立第二套角色/背包/开关状态。

异常/ensure控制、yield/块参数与非局部返回、带值break、super、类变量、复杂Hash键、正则运算、剩余RGSS接口、动态eval/反射/本机插件仍有明确诊断。动态接收者或未加载父类/方法会失败，生成不代表依赖已经可用。跨模块多层mixin及框架生命周期继续扩展，不把接口名存在当作完整适配。

ScriptRuntime.execute_unit显式加载一个单元；call_method/new_object在同一会话调用已加载的生成方法。不会自动跳过失败脚本并装作完成原加载过程。新游戏和读档清空会话；原生变量/开关/金币走既有存档。自定义全局对象、字段与完整对象图的持久化仍在0.47，当前不可用来继续已有自定义玩法进度。

## 生成工程源码结构

| 路径 | 职责 |
| --- | --- |
| legacy/ordered_scripts或legacy/ruby_scripts | 完整原Ruby、原加载顺序与镜像；只读追溯 |
| data/script_ast/*.json | 每个成功解析单元的完整节点 |
| data/script_semantics.json | AST作用域、各次定义、alias捕获版本、引用/依赖状态 |
| data/script_source_map.json | 原脚本ID/名称/行列/类/方法到生成文件、函数和行号 |
| data/script_units.json | 分别记录parsed/generated/event_integrated/runtime_verified、来源和诊断 |
| runtime/generated/script_NNNN.gd | 脚本库单元；program按顺序注册类与方法；method_N为实际GDScript方法实现 |
| runtime/generated/event_NNNNNN.gd | 已支持事件片段；显式执行，0.43前保持原事件占位 |
| runtime/scripts/ScriptRuntime.gd | 生成文件加载、显式调用与会话入口 |
| runtime/scripts/ScriptSemantics.gd | Ruby语义和现有游戏服务桥接 |
| runtime/scripts/其他.gd | 已有通用Godot运行时，不能都标为某个自定义Ruby脚本的自动转换 |

类重开可能跨多个生成文件，通过方法表保存版本；不是“一个Ruby类只能对应一个GDScript文件”。先查source_map的owner/ruby_method/generated_path/generated_method，再读函数实现；映射记录实际行号。原Ruby只用于首次迁移和追溯，后续开发目标是GDScript。重新转换和人工修改的冲突处理/工作区在0.48交付；本轮只新增输出，未覆盖历史工程或人工代码。

## 阶段验证边界

0.41验收AST结构与严格诊断；0.42验收生成代码编译、独立预期语义、定义顺序/alias、真实库方法显式调用，以及原生状态同步/失败回滚。两者不表示游戏功能验收完成，355/655、111和路线45仍未自动接入。没有另建用户演示场景；阶段证据见tests/VERIFICATION_v0.41_v0.42.md。
