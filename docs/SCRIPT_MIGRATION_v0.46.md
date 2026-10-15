# 0.46 实施说明

2026-10-13。仅匹配闪翼，按已授权的0.45→0.46→0.47顺序实施。0.46表内的界面、消息、地图半成品、存档展示、独立场景、演出和跟随职责已接到正式运行状态。源码结构与开发例子见[原Ruby到GDScript入口](FLASH_UI_GDSCRIPT_v0.46.md)，逐项状态见[清单](FLASH_SCRIPT_CHECKLIST_v0.45_v0.47.md)。特殊BOSS战排除；整体验收仍在脚本功能移植完成后进行。

## 原脚本与实际实现

| 任务 | 已接入的实际行为 | 主要GDScript |
| --- | --- | --- |
| 46-01/03 绘图与窗口 | 原H8/边框/卡片/渐变/蒙版/位图及文字工具，实际原生窗口职责、素材和字体 | FlashBitmap/Shape/Palette/Color/TextDrawing、UIResources、WindowBase及各Flash页面 |
| 46-02/16 系统与地图人物 | RuntimeState共享字段、图片/计时器/音频、640×640/60Hz、速度5/源跳跃、自主频度严格大于、事务人物参数、原106键常量 | CharacterMotion/Route、FlashCharacterBridge/Keyboard/Preferences、MapRuntime |
| 46-04/07 标题与HUD | 四模式标题、设置/音乐/成就，菜单权限/分类，主辅角色卡、HP/SP/经验、九格条、地图名/Topic、进退与模糊 | FlashTitleScreen/MenuScreen/PlayerHUD/Topic/SceneBackdrop |
| 46-05/06 消息与解释器 | 头像/名字/图标/定位/换行、提示/选择、等待/暂停/早唤醒、并行101、八行选择/文章连接、100/50双历史及L/Tab、Words和UTF-8文本流 | FlashMessage*、FlashTextRow/Stream、EventInterpreter/UIBroker/DialogueOverlay |
| 46-08–10 技能/回路/笔记 | 同一角色/库存/预测，配置/角色页签/卡片，回路锁/限制/候选/装卸/需求说明，笔记源有限分支与滚动 | FlashSkillPage/BlasticPage/NotePage及共享FlashActions |
| 46-11 灵视与显伤 | 四聚焦、实际敌人/物品、共享伤害与有效技能/行动卡、HP动画；地图伤害颜色及耐心提示 | FlashSightModel/Page、FlashEnemyMapLabels |
| 46-12 地图半成品 | 已有发现/区域/连接/布局/地图块/游标/预览/换图、实际M入口 | FlashMapSystem/Screen/Preview/Block/Cursor、FlashFloor/Region |
| 46-13 独立页与存档展示 | 飞行器/CP/物品/技能/装备/商店/调试，4096上限存档位、章节/种类/截图/队伍/说明/读写及返回 | FlashSceneRegistry/SelectionPage/CastingPage/EquipmentPage/DebugPage/ArchivePage/Data、MenuCoordinator |
| 46-15 演出与跟随 | 非阻塞冻结/模糊/滤镜/旁白/扫描线/闪回/碎屏模型、人物/图片消散、队伍跟随移动队列及换图清理 | FlashScreenEffects/EffectView/Unravel/BrokenScreen/Followers |

所有页面读取同一份0.45玩法状态，普通战斗技能继续编辑`runtime/generated/flash_skill_catalog.gd`。不执行Ruby或引入.NET、Win32 DLL。原数值公式保留，明确源码错误登记在`data/source_corrections.json`。共享缓存只读，位图/材质/消散纹理由实例持有。

脚本的角色/字段、人物参数、场景/演出和键盘计数先草稿后提交；失败整体回滚。解释器和路线按请求ID等待，取消或重开作废旧回调。消息、演出和跟随各由所属控制器推进一个时钟。人物事件移动仅修改该事件，不覆写玩家坐标。

原Map024 EV032的Message::TextRow片段修正Ruby控制字符误用；保留原文/原SHA，另存修正SHA并重新生成绑定。该源片段只构造文本行，没有显示动作，目标也不新增窗口。整个正式工程须由原Scripts.rxdata及原事件数据重新导出。

## 仍按原计划保留的边界

- 0.47继续完整对象关系、活动消息/演出/消散/跟随现场、设置/解锁跨启动保存、自动保存/撤回及剩余插件。0.46会拒绝保存不能还原的活动画面关系，不将其伪装成已完成持久化。
- 地图旧入口0244/0249/0250、旧EnemyDate、旧Scene_Skill、覆盖窗口和0267注释代码的真实加载关系见源码入口说明。已迁移半成品已有行为；原空BUFF/Help/音乐方法、未给出的笔记/回路预设/副手保持源状态。
- 原扫描线/闪回、默认冻结SE、碎屏SE/蒙版缺失时实际入口明确拒绝。内存夹具仅验证时间/粒子逻辑，不补写原素材。模糊由Godot/纯GDScript替代，不声称与闭源DLL逐像素一致。
- 飞行器返回原变量13选择值或stop，CP返回变量12；原源未实现的瞬间传送不补写。装备按最终六槽源行为提交，不发明原不存在的库存交换公式。
- 特殊BOSS、RM原生回合战/RTP/RM旧存档按已确定范围排除。

## 正式工程与验证

输出：`../output/0.46/final/黎之闪翼（开发中）_Godot`。原0.45正式工程保持冻结。新工程带源码对应、开发例子、版本清单和验证说明。原RM重新导出及完整检查结果见[验证记录](../tests/VERIFICATION_v0.46.md)。
