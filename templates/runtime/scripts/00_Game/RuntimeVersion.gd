## 职责：声明生成游戏使用的运行时版本，供界面、报告和兼容性检查读取。
##
## 调用方式：
##   preload("res://runtime/scripts/00_Game/RuntimeVersion.gd").VERSION 返回当前生成游戏的运行时版本字符串。
##
## 调用接口：
##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。
## 公开常量：VERSION。
## 接口说明结束。

extends RefCounted
# Overwritten by ProjectGenerator from the migrator's single version source.
const VERSION := "ver0.59"
