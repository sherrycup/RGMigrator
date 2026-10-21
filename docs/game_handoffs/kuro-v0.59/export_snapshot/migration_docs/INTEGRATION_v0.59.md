# 0.59 整合收尾与后续开发

2026-10-20用户授权实施。此版本完成约定范围的迁移整合、脚本文件命名及关键流程自查，用户人工验收另行记录。原工程只读，原数值公式、直接GDScript执行和首错退出规则保持。特殊BOSS、RM原生回合制战斗、RTP及RM旧存档继续排除；完整剧情通关和全部地图长期性能不由局部测试证明。

维护脚本和交付脚本移除文件名的Flash前缀，Editor_继续标识编辑器。Game_ActorState承载原自定义角色，ActorState保留标准数据库角色职责，二者仍按RuntimeState现有分派使用，不新增角色现场。测试中重名的Presentation和SaveRestart使用GamePresentationTests/GameSaveRestartTests。完整旧名到新名清单为tools/script_renames_v059.json，导出后在data/script_renames_v059.json；ScriptPaths保留旧名导航别名，直接preload使用当前路径。

生成的技能定义文件也改为runtime/generated/skill_catalog.gd；已登记的旧路径只作为数据指纹兼容别名，其他数据字节仍完整校验。文件名变化不意味着重命名原RM类、事件源码、内部flash_存档键或资源配置。原始来源和历史兼容字面量保持；维护文件的调用接口中文说明随真实声明同步。运行脚本无编辑器依赖，事件正文仍直接编辑、编译、保存和执行GDScript。

碎屏代码默认的sptx原素材缺失，本轮提供新生成的480×480、36区域、离散灰度分区图。由tools/generate_broken_screen_mask.py可复现，来源及SHA在runtime/assets/broken_screen_mask.json；这不是找回的原图，也没有复制“小蛋挞”的544×416图片。现有原图优先，仅缺少默认sptx/sptx.png时使用新图；其他缺图继续明确拒绝。原480像素处理范围、160像素裁切和90帧时序保持，尚未扩展为新分辨率全屏碎裂。

整合验证包括标题/难度/设置、新游戏、Message与历史、事件GDScript编辑、物品/菜单/档案、普通战斗、钥匙门/拾取、保存与读取、撤回、回标题；覆盖实际GPU、错误退出、0.58生成的旧档及分页表现现场。读档进度/BGM、唯一HUD物品栏和F7援护预览继续保留。首次资源准备仍有等待及帧峰值，新分辨率UI位置后置。自查结果和测量见tests/VERIFICATION_v0.59.md，不以代码文件数量或版本号替代实际验收。

后续游戏开发以最终Godot工程为主：地图/数据库/事件在addons/rgm_editor编辑，具体玩法在runtime/scripts按功能修改，技能定义在runtime/generated/skill_catalog.gd维护。原Ruby仅供对照。需要重新迁移时输出到独立新目录，再审阅合并游戏改动；不要用迁移模板覆盖已经创作的工程。迁移器主要维护确认的迁移错误与通用编辑器能力，新剧情、UI布局、角色技能及源半成品功能在游戏工程继续开发。
