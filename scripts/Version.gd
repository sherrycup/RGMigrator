## 职责：集中声明迁移器版本号与显示名称，供主界面、报告及工程生成器共用。
##
## 调用方式：
##   preload("res://scripts/Version.gd").VERSION 读取版本；DISPLAY_NAME 用于界面和报告。
##
## 调用接口：
##   本文件未声明额外公开方法；使用常量、继承接口或下列场景树回调。
## 公开常量：NAME、VERSION、DISPLAY_NAME。
## 接口说明结束。

class_name RGMigratorVersion
extends RefCounted

const NAME := "RGMigrator"
const VERSION := "ver0.59"
const DISPLAY_NAME := NAME + " " + VERSION
