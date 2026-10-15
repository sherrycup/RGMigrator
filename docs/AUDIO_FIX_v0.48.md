# 0.48 BGM反馈修复

2026-10-14用户反馈BGM无声而菜单音效正常。修复工程另建`../output/0.48/fix-audio-final/黎之闪翼（开发中）_Godot`，从原RM正式迁移，包含此前脚本工作区及性能修复；已有工程保留。最终结果见`tests/VERIFICATION_v0.48.md`的音频追加记录。

## 原因与修复

- `RmxpAssetCopier._probe_audio`原来把解码子进程整个日志中的ERROR视为素材损坏。Windows证书库读取失败属于引擎启动诊断；原7首MP3地图音乐实际解码成功却全部被隔离。现在以完整解码开始/结束标记限定日志范围，并核对输入SHA256、有效时长和子进程成功退出；真实解码错误、错误输入和未完成检查仍拒绝导入。
- 标题引用的`本田宗,tororo - 月明かり.mp2`是实际MPEG Layer II。标准Godot不默认支持该格式。迁移阶段使用可配置FFmpeg转换为16位PCM WAV，独立Godot解码通过才加入原名称索引；原MP2原样保留，`data/asset_conversions.json`记录原件和转换文件SHA256。生成游戏只加载WAV，不依赖FFmpeg、Python、.NET或原RM运行时。迁移器通过`rgmigrator/audio_converter_executable`工程设置或`RGMIGRATOR_FFMPEG`环境变量指定迁移工具；未配置或转换失败时仍保留原件并明确警告。
- 原0004/0046脚本在不存在RM配置时将音乐与音效音量置0。迁移不导入RM旧配置，导致初次运行静音。本次将**无已存配置**时两个默认音量修正为10，原0–10范围和音量乘法保留。已存设置中的0仍按静音读取，成就和音乐解锁不改写；这是源初始化错误的运行适配修正，不修改原RM脚本。
- `UIResources.play_sound`原先走Master，绕过全局音效音量。现在与事件SE、动画时序SE使用同一音效总线，独立于音乐总线，设置页的音效音量及静音实际生效。

## 使用和边界

在Godot中打开新工程的`project.godot`。若之前已经保存了0音量，在标题或菜单的“游戏设置”选择“背景音乐”，按右键调至10；已有静音设置不会自动覆盖。音乐解锁仍按源名单，音乐鉴赏页原来的空播放分支没有扩展。

原地图014/015/017/033/034/035/036引用的`城镇`音乐在输入工程中没有对应文件；保留缺失诊断，不补取RTP、不替换为其它歌曲。本次修复针对原工程已有的7首地图MP3和1首标题MP2，并不保证所有源引用都有素材。

## 检查

`tests/AudioImportTests.gd`实际读取8首原BGM，检查7首MP3字节和索引、MP2转换及来源哈希、错误MP3隔离、启动诊断和解码诊断区分。`tests/runtime/FlashAudioTests.gd`检查首次默认、已保存静音、旧配置数据保留、实际Title场景播放、全部地图MP3、重复播放、音频现场保存/恢复、菜单/动画音效总线和实际混音输出。

引擎格式边界依据：[Godot AudioStreamMP3文档](https://docs.godotengine.org/en/stable/classes/class_audiostreammp3.html)。本轮不编译定制引擎。
