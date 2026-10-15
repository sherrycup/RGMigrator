# 闪翼0.47依赖与生命周期审计

2026-10-14。只读核对339个脚本槽位及144个原事件片段，不执行Ruby。逐方法声明、alias、动态调用位置和对应服务见同名JSON。分类表示职责由生成代码或服务承担，不表示每一个原方法均自动转译。

## 本轮动态与原生替换

| 来源 | 分类 | 实际边界 |
| --- | --- | --- |
| 0274—0308 | user_excluded | Special BOSS battle remains excluded. |
| 0244/0249/0250/0257/0262/0267/0269 | overridden_undefined_or_commented | Final 0.46 service path is retained; old missing method dependencies fail with source diagnostics. 0267/0269 are commented rather than runtime sorting/UI plugins. |
| 0047/0139—0145/0186/0231/0312 | source_empty_or_missing | Original empty music/help/BUFF/menu branches and fixed achievement samples remain as authored; no new unlock/reward mechanics are invented. |
| 0053—0057/0070/0215—0221 | missing_original_data | Missing Deputy definition/exdata and circuit presets remain explicit source gaps. |
| 0310/0311 | missing_original_media | Missing SE/mask causes actual effect requests to fail; owned active effects now persist. |
| 0323 | no_original_video_asset_or_call | Source video tool is replaced; no supplied video file or event invocation exists. Codec playback cannot be claimed as validated against original media. |
| 0012/0020/0023/0025/0033/0266/0329/0333 | native_implementation_replaced | Purpose-specific Godot image/input/window/PNG/video/logging services replace native addresses, DLLs and console helpers. |
| 0019/0053/0070/0078/0086/0094/0096/0098/0108/0161/0165/0169/0331 | bounded_dynamic_services | Known source inputs use generated data/finite dispatch/owned model data; unknown new expressions and custom callbacks reject explicitly. |

## 逐脚本职责入口

| 序号 | 原名 | 分类 | GDScript入口 | 原方法数 |
| --- | --- | --- | --- | --- |
| 0003 | Global | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashKeyboard.gd, FlashPreferences.gd, FlashUtils.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 3 |
| 0004 | Global_Variables | service_adapted_with_original_retained | EventPersistence.gd, FlashFileStore.gd, FlashPreferences.gd, RuntimeState.gd, ScriptRuntime.gd | 4 |
| 0005 | Universal_Bind | service_adapted_with_original_retained | CustomDataState.gd, EventInterpreter.gd, EventPersistence.gd, EventUIBroker.gd, FlashUtils.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 12 |
| 0006 | 全局定义 | generated_and_service_adapted | CustomDataState.gd, EventPersistence.gd, FlashUtils.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 0 |
| 0009 | Sotrage | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, RmxpCache.gd, RuntimeState.gd, ScriptRuntime.gd | 2 |
| 0012 | []TKTK_Bitmap | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashMapSnapshot.gd, FlashPresentationState.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, RmxpCache.gd, RuntimeState.gd, ScriptRuntime.gd | 12 |
| 0018 | Object | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashUtils.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 2 |
| 0019 | Array | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashFloor.gd, FlashObjectCatalog.gd, FlashUtils.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 7 |
| 0020 | String | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashKeyboard.gd, FlashPreferences.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 3 |
| 0021 | Numeric | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashUtils.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 6 |
| 0022 | Color | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, RmxpCache.gd, RuntimeState.gd, ScriptRuntime.gd | 8 |
| 0023 | Bitmap | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashMapSnapshot.gd, FlashPresentationState.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, RmxpCache.gd, RuntimeState.gd, ScriptRuntime.gd | 22 |
| 0024 | Hash | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashUtils.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 1 |
| 0025 | RPG::Cache | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashBitmap.gd, FlashKeyboard.gd, FlashPreferences.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, RmxpCache.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 2 |
| 0026 | Tilemap | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, RmxpCache.gd, RuntimeState.gd, ScriptRuntime.gd | 25 |
| 0027 | Bitmap绘图追加 | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, RmxpCache.gd, RuntimeState.gd, ScriptRuntime.gd | 33 |
| 0030 | Shape | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, RmxpCache.gd, RuntimeState.gd, ScriptRuntime.gd | 6 |
| 0031 | Hexagon | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, RmxpCache.gd, RuntimeState.gd, ScriptRuntime.gd | 5 |
| 0032 | Graphics | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashKeyboard.gd, FlashPreferences.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, RmxpCache.gd, RuntimeState.gd, RuntimeVersion.gd, ScriptRuntime.gd | 5 |
| 0033 | WindowScaler | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashKeyboard.gd, FlashPreferences.gd, RuntimeState.gd, RuntimeVersion.gd, ScriptRuntime.gd, ScriptSemantics.gd | 6 |
| 0034 | RPG追加 | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashBitmap.gd, FlashShape.gd, FlashTextDrawing.gd, FlashTilemap.gd, FlashUtils.gd, FlashValueExtensions.gd, RmxpCache.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 9 |
| 0037 | DataBase | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashUtils.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 3 |
| 0040 | ->Sotrage | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashConfigPage.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, FlashUtils.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 4 |
| 0041 | Game_Temp | generated_and_service_adapted | CharacterMotion.gd, EventPersistence.gd, FlashActions.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashItemEffects.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 2 |
| 0042 | Game_System 1 | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 22 |
| 0043 | Game_System 2 | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashActions.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashHistory.gd, FlashItemEffects.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, Game.gd, MenuCoordinator.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 7 |
| 0044 | Game_Screen | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 6 |
| 0045 | Game_Picture | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 7 |
| 0046 | Game_Config | service_adapted_with_original_retained | EventPersistence.gd, FlashConfigPage.gd, FlashFileStore.gd, FlashKeyboard.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, RuntimeState.gd, RuntimeVersion.gd, ScriptRuntime.gd | 10 |
| 0047 | Game_Music | service_adapted_with_original_retained | EventPersistence.gd, FlashConfigPage.gd, FlashFileStore.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, RuntimeState.gd, ScriptRuntime.gd | 2 |
| 0048 | Sprite_Picture | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashMapBridge.gd, FlashRegion.gd, RuntimeState.gd, ScriptRuntime.gd | 3 |
| 0049 | Sprite_Timer | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashMapBridge.gd, FlashRegion.gd, RuntimeState.gd, ScriptRuntime.gd | 3 |
| 0052 | ->Sotrage | service_adapted_with_original_retained | EventPersistence.gd, FlashActions.gd, FlashItemEffects.gd, RuntimeState.gd, ScriptRuntime.gd | 21 |
| 0053 | Game_Object | service_adapted_with_original_retained | EventPersistence.gd, FlashFloor.gd, FlashObjectCatalog.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 3 |
| 0054 | Game_Item | service_adapted_with_original_retained | EventPersistence.gd, FlashObjectCatalog.gd, RuntimeState.gd, ScriptRuntime.gd | 9 |
| 0055 | Game_Weapon | service_adapted_with_original_retained | EventPersistence.gd, FlashObjectCatalog.gd, RuntimeState.gd, ScriptRuntime.gd | 10 |
| 0056 | Game_Armor | service_adapted_with_original_retained | EventPersistence.gd, FlashObjectCatalog.gd, RuntimeState.gd, ScriptRuntime.gd | 10 |
| 0057 | Game_Ornament | service_adapted_with_original_retained | EventPersistence.gd, FlashObjectCatalog.gd, RuntimeState.gd, ScriptRuntime.gd | 10 |
| 0060 | ->Sotrage | generated_and_service_adapted | EventPersistence.gd, FlashActorState.gd, FlashBattleCatalog.gd, FlashGameplay.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 4 |
| 0061 | ->Storage(技能文本) | generated_and_service_adapted | EventPersistence.gd, FlashBattleCatalog.gd, FlashGameplay.gd, RuntimeState.gd, ScriptRuntime.gd | 2 |
| 0062 | Skill 1 | service_adapted_with_original_retained | EventPersistence.gd, FlashBattleCatalog.gd, FlashGameplay.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 14 |
| 0064 | Skill 3 | generated_and_service_adapted | EventPersistence.gd, FlashBattleCatalog.gd, FlashGameplay.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 1 |
| 0065 | Game_Battler 1 | service_adapted_with_original_retained | EventPersistence.gd, FlashActorState.gd, FlashBattlerRules.gd, FlashEnemyState.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 23 |
| 0066 | Game_Battler 2 | service_adapted_with_original_retained | EventPersistence.gd, FlashActorState.gd, FlashBattlerRules.gd, FlashEnemyState.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 9 |
| 0067 | Game_Battler 3 | generated_and_service_adapted | EventPersistence.gd, FlashActorState.gd, FlashBattlerRules.gd, FlashEnemyState.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 1 |
| 0068 | Game_Actor 1 | service_adapted_with_original_retained | EventPersistence.gd, FlashActions.gd, FlashActorState.gd, FlashBattlerRules.gd, FlashBlastic.gd, FlashEnemyState.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, ScriptSemantics.gd | 29 |
| 0069 | Game_Actor 2 | service_adapted_with_original_retained | EventPersistence.gd, FlashActorState.gd, FlashBattlerRules.gd, FlashEnemyState.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 9 |
| 0070 | Game_Enemy 1 | service_adapted_with_original_retained | EventPersistence.gd, FlashActorState.gd, FlashBattlerRules.gd, FlashEnemyState.gd, FlashFloor.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashValueExtensions.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, ScriptSemantics.gd | 16 |
| 0071 | Game_Enemy 2 | service_adapted_with_original_retained | EventPersistence.gd, FlashActorState.gd, FlashBattlerRules.gd, FlashEnemyState.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 10 |
| 0072 | BattleSystem | service_adapted_with_original_retained | EventPersistence.gd, FlashActions.gd, FlashBattleRegistry.gd, FlashBattleSimulator.gd, FlashFollowers.gd, FlashGameplay.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 187 |
| 0073 | SkillRegistry | service_adapted_with_original_retained | EventPersistence.gd, FlashBattleRegistry.gd, FlashBattleSimulator.gd, RuntimeState.gd, ScriptRuntime.gd | 1 |
| 0075 | Battle_Data | service_adapted_with_original_retained | EventPersistence.gd, FlashGameplay.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 17 |
| 0076 | Delay_Ctrl | service_adapted_with_original_retained | EventPersistence.gd, FlashGameplay.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 16 |
| 0078 | ▲Game_Party | service_adapted_with_original_retained | EventPersistence.gd, FlashActions.gd, FlashActorState.gd, FlashFloor.gd, FlashFollowers.gd, FlashGameplay.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashValueExtensions.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, ScriptSemantics.gd | 24 |
| 0079 | Game_Troop | service_adapted_with_original_retained | EventPersistence.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashMapDamage.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 11 |
| 0082 | Game_Switches | generated_and_service_adapted | EventPersistence.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 3 |
| 0083 | Game_Variables | generated_and_service_adapted | EventPersistence.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 3 |
| 0084 | Game_SelfSwitches | generated_and_service_adapted | EventPersistence.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 3 |
| 0085 | Game_Actors | generated_and_service_adapted | EventPersistence.gd, FlashActorState.gd, FlashBattlerRules.gd, FlashEnemyState.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 2 |
| 0086 | Game_Equipment | service_adapted_with_original_retained | EventPersistence.gd, FlashFloor.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashValueExtensions.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, ScriptSemantics.gd | 2 |
| 0087 | Game_Troops | service_adapted_with_original_retained | EventPersistence.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashMapDamage.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 2 |
| 0088 | Game_Blastics | generated_and_service_adapted | EventPersistence.gd, FlashActions.gd, FlashBlastic.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 2 |
| 0091 | ->Sotrage | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashMapBridge.gd, FlashRegion.gd, RuntimeState.gd, ScriptRuntime.gd | 5 |
| 0092 | Game_CommonEvent | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashMapBridge.gd, FlashRegion.gd, RuntimeState.gd, ScriptRuntime.gd | 7 |
| 0093 | Game_Character 1 | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 18 |
| 0094 | Game_Character 2 | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, FlashValueExtensions.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, ScriptSemantics.gd | 8 |
| 0095 | Game_Character 3 | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 25 |
| 0096 | Game_Event | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashActions.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashGameplay.gd, FlashHistory.gd, FlashMapBridge.gd, FlashMapDamage.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, FlashValueExtensions.gd, Game.gd, MenuCoordinator.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, ScriptSemantics.gd | 19 |
| 0097 | Game_Player 1 | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashHistory.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, Game.gd, MenuCoordinator.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 13 |
| 0098 | Game_Player 2 | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashMapDamage.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, FlashValueExtensions.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, ScriptSemantics.gd | 9 |
| 0099 | ▲Sprite_Character | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashMapBridge.gd, FlashRegion.gd, RuntimeState.gd, ScriptRuntime.gd | 4 |
| 0102 | ->Sotrage | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashMapBridge.gd, FlashRegion.gd, RuntimeState.gd, ScriptRuntime.gd | 1 |
| 0103 | ▲●Game_Map 1 | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 16 |
| 0104 | Game_Map 2 | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashMapDamage.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 12 |
| 0105 | Spriteset_Map | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBridge.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 4 |
| 0108 | Game_Floor | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBlock.gd, FlashMapBridge.gd, FlashMapPreview.gd, FlashMapScreen.gd, FlashMapSystem.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, FlashValueExtensions.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, ScriptSemantics.gd | 4 |
| 0109 | Game_Region | service_adapted_with_original_retained | CharacterMotion.gd, EventPersistence.gd, FlashCharacterBridge.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapBlock.gd, FlashMapBridge.gd, FlashMapPreview.gd, FlashMapScreen.gd, FlashMapSystem.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashRegion.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 4 |
| 0111 | ▲Window_Base | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 37 |
| 0112 | Window_Selectable | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 10 |
| 0113 | Window_Command | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 5 |
| 0114 | Window_Help | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 4 |
| 0116 | ▲Window_Item | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 5 |
| 0117 | ★Window_Flytofloor | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 5 |
| 0118 | ★Window_CP | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 5 |
| 0119 | Window_Skill | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 5 |
| 0120 | Window_SkillStatus | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 2 |
| 0121 | Window_Target | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 3 |
| 0122 | ▲Window_EquipLeft | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 3 |
| 0123 | Window_EquipRight | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 4 |
| 0124 | ▲Window_EquipItem | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 5 |
| 0125 | Window_Status | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 3 |
| 0126 | ▲Window_SaveFile | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 4 |
| 0127 | Window_ShopCommand_New | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 4 |
| 0128 | Window_ShopBuy | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 5 |
| 0129 | Window_ShopSell | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 5 |
| 0130 | Window_ShopNumber | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 5 |
| 0131 | Window_ShopStatus | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 3 |
| 0132 | Window_NameEdit | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 7 |
| 0133 | ▲Window_InputNumber | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 6 |
| 0134 | ▲Window_Message | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 7 |
| 0135 | Window_DebugLeft | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 4 |
| 0136 | Window_DebugRight | service_adapted_with_original_retained | EventPersistence.gd, FlashArchivePage.gd, RuntimeState.gd, ScriptRuntime.gd, WindowBase.gd, WindowCommand.gd, WindowSelectable.gd | 4 |
| 0139 | ▲Scene_Title | service_adapted_with_original_retained | EventPersistence.gd, FlashConfigPage.gd, FlashFileStore.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, RuntimeState.gd, ScriptRuntime.gd | 21 |
| 0140 | Window_BackGround | service_adapted_with_original_retained | EventPersistence.gd, FlashConfigPage.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, RuntimeState.gd, ScriptRuntime.gd | 7 |
| 0141 | Window_Mode | service_adapted_with_original_retained | EventPersistence.gd, FlashConfigPage.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, RuntimeState.gd, ScriptRuntime.gd | 9 |
| 0142 | Window_Title | service_adapted_with_original_retained | EventPersistence.gd, FlashConfigPage.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, RuntimeState.gd, ScriptRuntime.gd | 20 |
| 0143 | Window_Config | service_adapted_with_original_retained | EventPersistence.gd, FlashConfigPage.gd, FlashFileStore.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, RuntimeState.gd, ScriptRuntime.gd | 16 |
| 0144 | Window_Music | service_adapted_with_original_retained | EventPersistence.gd, FlashConfigPage.gd, FlashFileStore.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, RuntimeState.gd, ScriptRuntime.gd | 19 |
| 0145 | Window_Merit | service_adapted_with_original_retained | EventPersistence.gd, FlashConfigPage.gd, FlashFileStore.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, RuntimeState.gd, ScriptRuntime.gd | 23 |
| 0148 | ->Storage | generated_and_service_adapted | EventPersistence.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 1 |
| 0149 | Message 1 | service_adapted_with_original_retained | EventPersistence.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 12 |
| 0150 | Message 2 | service_adapted_with_original_retained | EventPersistence.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 2 |
| 0151 | Message::TextRow | service_adapted_with_original_retained | EventPersistence.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 10 |
| 0152 | Message::TextBox 1 | service_adapted_with_original_retained | EventPersistence.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 28 |
| 0153 | Message::TextBox 2 | service_adapted_with_original_retained | EventPersistence.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 7 |
| 0154 | Message::HintBox 1 | service_adapted_with_original_retained | EventPersistence.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 28 |
| 0155 | Message::HintBox 2 | service_adapted_with_original_retained | EventPersistence.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 6 |
| 0156 | Message::Words | generated_and_service_adapted | EventPersistence.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 1 |
| 0157 | Message_Memory | service_adapted_with_original_retained | EventPersistence.gd, FlashFollowers.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashTextStream.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 16 |
| 0159 | Interpreter 1 | service_adapted_with_original_retained | EventInterpreter.gd, EventPersistence.gd, EventUIBroker.gd, RuntimeState.gd, ScriptRuntime.gd | 11 |
| 0160 | Interpreter 2 | service_adapted_with_original_retained | EventInterpreter.gd, EventPersistence.gd, EventUIBroker.gd, RuntimeState.gd, ScriptRuntime.gd | 5 |
| 0161 | Interpreter 3 | service_adapted_with_original_retained | EventInterpreter.gd, EventPersistence.gd, EventUIBroker.gd, FlashFloor.gd, FlashObjectCatalog.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 18 |
| 0162 | Interpreter 4 | service_adapted_with_original_retained | EventInterpreter.gd, EventPersistence.gd, EventUIBroker.gd, RuntimeState.gd, ScriptRuntime.gd | 15 |
| 0163 | ▲Interpreter 5 | service_adapted_with_original_retained | EventInterpreter.gd, EventPersistence.gd, EventUIBroker.gd, RuntimeState.gd, ScriptRuntime.gd | 30 |
| 0164 | Interpreter 6 | service_adapted_with_original_retained | EventInterpreter.gd, EventPersistence.gd, EventUIBroker.gd, RuntimeState.gd, ScriptRuntime.gd | 18 |
| 0165 | Interpreter 7 | service_adapted_with_original_retained | EventInterpreter.gd, EventPersistence.gd, EventUIBroker.gd, FlashFloor.gd, FlashObjectCatalog.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 15 |
| 0166 | ▲Scene_Menu | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 5 |
| 0169 | Game_FileData | service_adapted_with_original_retained | EventPersistence.gd, FlashFloor.gd, FlashFollowers.gd, FlashHistory.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashValueExtensions.gd, Game.gd, MenuCoordinator.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, ScriptSemantics.gd | 5 |
| 0170 | Window_FileChapter | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashSceneRegistry.gd, RuntimeState.gd, ScriptRuntime.gd | 11 |
| 0171 | Window_FileKind | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashSceneRegistry.gd, RuntimeState.gd, ScriptRuntime.gd | 10 |
| 0172 | Window_MapSnap | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashSceneRegistry.gd, RuntimeState.gd, ScriptRuntime.gd | 12 |
| 0173 | Window_File | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashFollowers.gd, FlashHistory.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashSceneRegistry.gd, Game.gd, MenuCoordinator.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 34 |
| 0174 | Window_FileTips | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashSceneRegistry.gd, RuntimeState.gd, ScriptRuntime.gd | 13 |
| 0177 | Window_ItemCategory | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 17 |
| 0178 | Window_ItemHelp | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 9 |
| 0179 | Window_ItemDesc | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 5 |
| 0180 | Window_Item | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 20 |
| 0181 | Window_Gold | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 9 |
| 0182 | Window_ItemConfig | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 17 |
| 0183 | ※Window_ItemBar | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 22 |
| 0186 | Window_State | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 19 |
| 0187 | Window_Topic | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 9 |
| 0188 | Window_MapName | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 8 |
| 0191 | Message_Controller | service_adapted_with_original_retained | EventInterpreter.gd, EventPersistence.gd, EventUIBroker.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 8 |
| 0193 | 药品库 | generated_and_service_adapted | EventPersistence.gd, FlashActions.gd, FlashItemEffects.gd, RuntimeState.gd, ScriptRuntime.gd | 1 |
| 0197 | ■●Window_PlayerData | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 40 |
| 0198 | △Window_MenuCommand | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 15 |
| 0200 | ▲Scene_Map 1 | service_adapted_with_original_retained | EventPersistence.gd, FlashGameplay.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 17 |
| 0201 | ▲Scene_Map 2 | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 7 |
| 0202 | ▲Scene_Map 3 | service_adapted_with_original_retained | EventPersistence.gd, FlashGameplay.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 28 |
| 0203 | ▲Scene_Map 4 | service_adapted_with_original_retained | EventPersistence.gd, FlashItemPresets.gd, FlashMapShortcuts.gd, FlashMenuScreen.gd, FlashPlayerHUD.gd, RuntimeState.gd, ScriptRuntime.gd | 5 |
| 0207 | Window_Skill | service_adapted_with_original_retained | EventPersistence.gd, FlashSkillConfig.gd, FlashSkillPage.gd, RuntimeState.gd, ScriptRuntime.gd | 11 |
| 0208 | Window_SkillHelp | service_adapted_with_original_retained | EventPersistence.gd, FlashSkillConfig.gd, FlashSkillPage.gd, RuntimeState.gd, ScriptRuntime.gd | 10 |
| 0209 | Window_SkillCategory | service_adapted_with_original_retained | EventPersistence.gd, FlashSkillConfig.gd, FlashSkillPage.gd, RuntimeState.gd, ScriptRuntime.gd | 28 |
| 0212 | ->Storage(结晶回路追加定义) | generated_and_service_adapted | EventPersistence.gd, FlashActions.gd, FlashBlastic.gd, RuntimeState.gd, ScriptRuntime.gd | 1 |
| 0213 | ->Storage | generated_and_service_adapted | EventPersistence.gd, FlashActions.gd, FlashBlastic.gd, RuntimeState.gd, ScriptRuntime.gd | 6 |
| 0214 | Game_Blastic | generated_and_service_adapted | EventPersistence.gd, FlashActions.gd, FlashBlastic.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 8 |
| 0215 | Window_Blastic | service_adapted_with_original_retained | EventPersistence.gd, FlashBlastic.gd, FlashBlasticPage.gd, RuntimeState.gd, ScriptRuntime.gd | 16 |
| 0216 | Window_BlasticAtrri | service_adapted_with_original_retained | EventPersistence.gd, FlashBlastic.gd, FlashBlasticPage.gd, RuntimeState.gd, ScriptRuntime.gd | 12 |
| 0217 | Window_BlasticEquip | service_adapted_with_original_retained | EventPersistence.gd, FlashBlastic.gd, FlashBlasticPage.gd, RuntimeState.gd, ScriptRuntime.gd | 25 |
| 0218 | Window_BlasticEquipDesc | service_adapted_with_original_retained | EventPersistence.gd, FlashBlastic.gd, FlashBlasticPage.gd, RuntimeState.gd, ScriptRuntime.gd | 11 |
| 0219 | Window_BlasticGroup | service_adapted_with_original_retained | EventPersistence.gd, FlashBlastic.gd, FlashBlasticPage.gd, RuntimeState.gd, ScriptRuntime.gd | 17 |
| 0220 | Window_BlasticTitle | service_adapted_with_original_retained | EventPersistence.gd, FlashBlastic.gd, FlashBlasticPage.gd, RuntimeState.gd, ScriptRuntime.gd | 10 |
| 0221 | Window_BlasticCrystal | service_adapted_with_original_retained | EventPersistence.gd, FlashBlastic.gd, FlashBlasticPage.gd, RuntimeState.gd, ScriptRuntime.gd | 23 |
| 0224 | ->Storage | generated_and_service_adapted | EventPersistence.gd, FlashNotePage.gd, RuntimeState.gd, ScriptRuntime.gd | 2 |
| 0225 | Window_NoteCommand | service_adapted_with_original_retained | EventPersistence.gd, FlashNotePage.gd, RuntimeState.gd, ScriptRuntime.gd | 16 |
| 0226 | Window_NoteSelect | service_adapted_with_original_retained | EventPersistence.gd, FlashNotePage.gd, RuntimeState.gd, ScriptRuntime.gd | 19 |
| 0227 | Window_NoteDesc | service_adapted_with_original_retained | EventPersistence.gd, FlashNotePage.gd, RuntimeState.gd, ScriptRuntime.gd | 10 |
| 0231 | Window_SightMap | service_adapted_with_original_retained | EventPersistence.gd, FlashSightModel.gd, FlashSightPage.gd, RuntimeState.gd, ScriptRuntime.gd | 34 |
| 0232 | Window_SightDesc | service_adapted_with_original_retained | EventPersistence.gd, FlashSightModel.gd, FlashSightPage.gd, RuntimeState.gd, ScriptRuntime.gd | 12 |
| 0233 | Window_Enemy | service_adapted_with_original_retained | EventPersistence.gd, FlashSightModel.gd, FlashSightPage.gd, RuntimeState.gd, ScriptRuntime.gd | 38 |
| 0235 | Window_EnemySkill | service_adapted_with_original_retained | EventPersistence.gd, FlashSightModel.gd, FlashSightPage.gd, RuntimeState.gd, ScriptRuntime.gd | 19 |
| 0236 | Window_EnemyAction | service_adapted_with_original_retained | EventPersistence.gd, FlashSightModel.gd, FlashSightPage.gd, RuntimeState.gd, ScriptRuntime.gd | 11 |
| 0237 | Window_EnmeyAction2 | service_adapted_with_original_retained | EventPersistence.gd, FlashSightModel.gd, FlashSightPage.gd, RuntimeState.gd, ScriptRuntime.gd | 28 |
| 0238 | Window_SightHelp | service_adapted_with_original_retained | EventPersistence.gd, FlashSightModel.gd, FlashSightPage.gd, RuntimeState.gd, ScriptRuntime.gd | 17 |
| 0239 | Window_EnemyList | service_adapted_with_original_retained | EventPersistence.gd, FlashSightModel.gd, FlashSightPage.gd, RuntimeState.gd, ScriptRuntime.gd | 15 |
| 0240 | Window_ItemList | service_adapted_with_original_retained | EventPersistence.gd, FlashSightModel.gd, FlashSightPage.gd, RuntimeState.gd, ScriptRuntime.gd | 15 |
| 0244 | Window_RD_Map | service_adapted_with_original_retained | EventPersistence.gd, FlashMapBlock.gd, FlashMapPreview.gd, FlashMapScreen.gd, FlashMapSystem.gd, RuntimeState.gd, ScriptRuntime.gd | 8 |
| 0245 |   —>相关定义 | service_adapted_with_original_retained | EventPersistence.gd, FlashMapBlock.gd, FlashMapPreview.gd, FlashMapScreen.gd, FlashMapSystem.gd, RuntimeState.gd, ScriptRuntime.gd | 6 |
| 0246 | Game_MapSystem | service_adapted_with_original_retained | EventPersistence.gd, FlashFollowers.gd, FlashMapBlock.gd, FlashMapPreview.gd, FlashMapScreen.gd, FlashMapSystem.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 22 |
| 0247 | Game_MapBlock | service_adapted_with_original_retained | EventPersistence.gd, FlashFollowers.gd, FlashMapBlock.gd, FlashMapPreview.gd, FlashMapScreen.gd, FlashMapSystem.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 6 |
| 0248 | Window_Map | service_adapted_with_original_retained | EventPersistence.gd, FlashMapBlock.gd, FlashMapPreview.gd, FlashMapScreen.gd, FlashMapSystem.gd, RuntimeState.gd, ScriptRuntime.gd | 12 |
| 0249 | Window_Map_Selct | service_adapted_with_original_retained | EventPersistence.gd, FlashMapBlock.gd, FlashMapPreview.gd, FlashMapScreen.gd, FlashMapSystem.gd, RuntimeState.gd, ScriptRuntime.gd | 9 |
| 0250 | Sprite_MapBlock | service_adapted_with_original_retained | EventPersistence.gd, FlashMapBlock.gd, FlashMapPreview.gd, FlashMapScreen.gd, FlashMapSystem.gd, RuntimeState.gd, ScriptRuntime.gd | 3 |
| 0251 | Spriteset_MapSystem | service_adapted_with_original_retained | EventPersistence.gd, FlashMapBlock.gd, FlashMapPreview.gd, FlashMapScreen.gd, FlashMapSystem.gd, RuntimeState.gd, ScriptRuntime.gd | 15 |
| 0254 | ★Scene_Flytofloor | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashGameplay.gd, FlashSceneRegistry.gd, RuntimeState.gd, ScriptRuntime.gd | 4 |
| 0255 | ★Scene_CP | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashGameplay.gd, FlashSceneRegistry.gd, RuntimeState.gd, ScriptRuntime.gd | 4 |
| 0256 | ▲Scene_Item | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashGameplay.gd, FlashSceneRegistry.gd, RuntimeState.gd, ScriptRuntime.gd | 4 |
| 0257 | Scene_Skill | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashGameplay.gd, FlashSceneRegistry.gd, FlashSkillConfig.gd, FlashSkillPage.gd, RuntimeState.gd, ScriptRuntime.gd | 5 |
| 0258 | ▲Scene_Equip | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashGameplay.gd, FlashSceneRegistry.gd, RuntimeState.gd, ScriptRuntime.gd | 6 |
| 0259 | Scene_Shop_new | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashGameplay.gd, FlashSceneRegistry.gd, RuntimeState.gd, ScriptRuntime.gd | 6 |
| 0260 | Scene_Debug | service_adapted_with_original_retained | EventPersistence.gd, FlashArchiveData.gd, FlashArchivePage.gd, FlashSceneRegistry.gd, RuntimeState.gd, ScriptRuntime.gd | 4 |
| 0262 | ■●Window_EnemyDate | service_adapted_with_original_retained | EventPersistence.gd, FlashSightModel.gd, FlashSightPage.gd, RuntimeState.gd, ScriptRuntime.gd | 9 |
| 0263 | ★Item caculator | generated_and_service_adapted | EventPersistence.gd, FlashActions.gd, FlashItemEffects.gd, RuntimeState.gd, ScriptRuntime.gd | 2 |
| 0265 | ■Window_Version | service_adapted_with_original_retained | EventPersistence.gd, FlashConfigPage.gd, FlashPreferences.gd, FlashTitleExtrasPage.gd, FlashTitleScreen.gd, RuntimeState.gd, ScriptRuntime.gd | 2 |
| 0266 | ■full kboard | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashKeyboard.gd, FlashPreferences.gd, RuntimeState.gd, RuntimeVersion.gd, ScriptRuntime.gd, ScriptSemantics.gd | 3 |
| 0270 | ■GPRA_TextStream | service_adapted_with_original_retained | EventPersistence.gd, FlashMessageBoxState.gd, FlashMessageController.gd, FlashMessageLayout.gd, FlashTextStream.gd, RuntimeState.gd, ScriptRuntime.gd | 4 |
| 0275 | ■Skill追加 | excluded_special_boss | 排除或历史原文 | 4 |
| 0276 | ■RPG相关追加 | excluded_special_boss | 排除或历史原文 | 7 |
| 0277 | ObservableBattler | excluded_special_boss | 排除或历史原文 | 5 |
| 0278 | Scene_BossBattle 1 | excluded_special_boss | 排除或历史原文 | 5 |
| 0279 | Scene_BossBattle 2 | excluded_special_boss | 排除或历史原文 | 3 |
| 0280 | Scene_BossBattle 3 | excluded_special_boss | 排除或历史原文 | 2 |
| 0281 | Scene_BossBattle 4 | excluded_special_boss | 排除或历史原文 | 1 |
| 0282 | Game_BossBattle_Data | excluded_special_boss | 排除或历史原文 | 13 |
| 0283 | ■■Temp_Battler | excluded_special_boss | 排除或历史原文 | 8 |
| 0284 | Game_Boss_Battler | excluded_special_boss | 排除或历史原文 | 27 |
| 0285 | Game_Boss_Actor | excluded_special_boss | 排除或历史原文 | 4 |
| 0286 | Game_Boss_Enemy | excluded_special_boss | 排除或历史原文 | 3 |
| 0287 | Game_Boss_Tactical | excluded_special_boss | 排除或历史原文 | 3 |
| 0288 | Battle_Calculator | excluded_special_boss | 排除或历史原文 | 14 |
| 0289 | Window_Boss_Command | excluded_special_boss | 排除或历史原文 | 21 |
| 0290 | Window_BCDesc | excluded_special_boss | 排除或历史原文 | 6 |
| 0291 | Window_BCHelp | excluded_special_boss | 排除或历史原文 | 8 |
| 0292 | Window_BDetail | excluded_special_boss | 排除或历史原文 | 0 |
| 0293 | Arrow_Base | excluded_special_boss | 排除或历史原文 | 4 |
| 0294 | Arrow_Enemy | excluded_special_boss | 排除或历史原文 | 6 |
| 0295 | Arrow_Actor | excluded_special_boss | 排除或历史原文 | 5 |
| 0296 | Animation_Damage | excluded_special_boss | 排除或历史原文 | 6 |
| 0298 |  | excluded_special_boss | 排除或历史原文 | 11 |
| 0299 | Sprite_BossStatus | excluded_special_boss | 排除或历史原文 | 31 |
| 0300 | Screen_BossBattle | excluded_special_boss | 排除或历史原文 | 7 |
| 0301 | ●Sprite_AT_List | excluded_special_boss | 排除或历史原文 | 15 |
| 0302 | ->Sprite_AT_Block | excluded_special_boss | 排除或历史原文 | 17 |
| 0304 | Sprite_Boss_Character | excluded_special_boss | 排除或历史原文 | 3 |
| 0305 | Spriteset_BossBattle | excluded_special_boss | 排除或历史原文 | 3 |
| 0306 | Battle_Manager | excluded_special_boss | 排除或历史原文 | 14 |
| 0310 | Game_Engine | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashBrokenScreen.gd, FlashFollowers.gd, FlashMapSnapshot.gd, FlashPresentationState.gd, FlashScreenEffects.gd, FlashUnravel.gd, RuntimeState.gd, ScriptRuntime.gd | 12 |
| 0311 | 碎屏 | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashBrokenScreen.gd, FlashFollowers.gd, FlashMapSnapshot.gd, FlashPresentationState.gd, FlashScreenEffects.gd, FlashUnravel.gd, RuntimeState.gd, ScriptRuntime.gd | 6 |
| 0312 | 游戏帮助 | service_adapted_with_original_retained | EventPersistence.gd, FlashBrokenScreen.gd, FlashFollowers.gd, FlashScreenEffects.gd, FlashUnravel.gd, RuntimeState.gd, ScriptRuntime.gd | 5 |
| 0315 | Utils | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashBrokenScreen.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashScreenEffects.gd, FlashUnravel.gd, FlashUtils.gd, FlashValueExtensions.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd, ScriptSemantics.gd | 10 |
| 0317 | Actor_Init | generated_and_service_adapted | EventPersistence.gd, FlashActorState.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 1 |
| 0318 | Level_Up | generated_and_service_adapted | EventPersistence.gd, FlashActorState.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 1 |
| 0320 | BackSpace(撤回) | service_adapted_with_original_retained | EventPersistence.gd, FlashHistory.gd, Game.gd, MenuCoordinator.gd, RuntimeState.gd, ScriptRuntime.gd | 2 |
| 0323 | Movie_Player | service_adapted_with_original_retained | EventInterpreter.gd, EventPersistence.gd, FlashMoviePlayer.gd, RuntimeState.gd, ScriptRuntime.gd | 16 |
| 0329 | 航拍 | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashMapSnapshot.gd, FlashPresentationState.gd, RuntimeState.gd, ScriptRuntime.gd | 20 |
| 0330 | 行走图 | service_adapted_with_original_retained | EventPersistence.gd, FlashBrokenScreen.gd, FlashFollowers.gd, FlashScreenEffects.gd, FlashUnravel.gd, RuntimeState.gd, ScriptRuntime.gd | 7 |
| 0331 | 位图消逝 | service_adapted_with_original_retained | EventPersistence.gd, FlashBitmap.gd, FlashBrokenScreen.gd, FlashFloor.gd, FlashFollowers.gd, FlashMapSnapshot.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashScreenEffects.gd, FlashUnravel.gd, FlashValueExtensions.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 24 |
| 0332 | 跟随 | service_adapted_with_original_retained | EventPersistence.gd, FlashBrokenScreen.gd, FlashFollowers.gd, FlashObjectCatalog.gd, FlashPresentationState.gd, FlashScreenEffects.gd, FlashUnravel.gd, RuntimeState.gd, SaveCodec.gd, SaveGraph.gd, ScriptRuntime.gd | 51 |
| 0333 | 临时debug | service_adapted_with_original_retained | CustomDataState.gd, EventPersistence.gd, FlashKeyboard.gd, FlashPreferences.gd, RuntimeState.gd, ScriptRuntime.gd, ScriptSemantics.gd | 4 |
| 0337 | Main | service_adapted_with_original_retained | EventPersistence.gd, FlashKeyboard.gd, FlashPreferences.gd, RuntimeState.gd, RuntimeVersion.gd, ScriptRuntime.gd | 0 |

## 恢复时的处理

SaveGraph保留共享/循环关系和类型化键。SaveCodec先验证全部数据与生成方法来源，再安装同一RuntimeState。RuntimeState重置旧执行后恢复角色、对象缓存、变量和脚本类/方法；EventPersistence重建等待token和界面请求编号；FlashPresentationState复原活动消息、冻结/演出/消散和跟随。新游戏清空单进度数据；FlashPreferences独立保存跨启动配置。撤回沿用变量25及100条循环历史，且只在原玩家触发条件下自动记录。
