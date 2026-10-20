"""Canonical script groups and source navigation for the 0.50 layout.

Run --apply once to relocate the old flat tree; --refresh-index only adds paths
for newly grouped files without rewriting historical compatibility strings.
--check verifies the maintained
layout and generated path registry. Runtime imports never use this Python tool.
"""

from pathlib import Path
import argparse
import json
import posixpath
import re
from sync_script_headers import with_header

REPO = Path(__file__).resolve().parents[1]
RUNTIME_ROOT = "templates/runtime/scripts"
EDITOR_ROOT = "templates/editor/addons/rgm_editor"
RUNTIME_GROUPS = {
    "00_Game": "RuntimeState RuntimeData RuntimeVersion Game_ActorInit ActorState ActorParameters Game_ActorState ActorFields EnemyState ObjectCatalog CustomDataState CustomDataTags SystemSettings ScreenState PictureState WeatherState MapViewState MapEffectsState GameTimer InventoryService ActorEventService CommonEventUse Preferences",
    "01_Battle": "BattleCache BattleCatalog BattleRegistry BattlerRules BattleSimulator BattleSkillDefinition BattleStateContainer DamageWorker EnemyAbilities ActionOrder Gameplay Actions ItemEffects Blastic",
    "02_Event": "EventCommandCatalog EventExecutionContext EventInput EventInterpreter EventMessage EventPersistence EventScheduler EventUIBroker EventValueResolver EventWait CharacterRoute NativeScriptSource NativeEventContext NativeEventTask EventScriptAPI EventScriptValue",
    "03_Map": "CharacterMotion CharacterSprite MapCamera MapCharacter MapEvent MapRuntime MapTileRow MapOcclusion PlayerController TilesetLayout CharacterBridge MapBridge Floor Region Followers Tilemap MapDamage EnemyMapLabels MapShortcuts PlayerHUD MapHUD Topic MapEffectsRenderer ScreenRenderer PictureSprite WeatherRenderer",
    "04_UI_Common": "WindowBase WindowCommand WindowSelectable UIResources UISpriteset UILayout UITextLayout UITextBlock UITransition UIInput WindowDrawing PageSurface Bitmap Color Palette Shape TextDrawing SceneBackdrop",
    "05_Title": "Title TitleScreen TitleLayout ConfigPage TitleExtrasPage Gameover",
    "06_Message": "DialogueOverlay NameInput MessageBoxState MessageController MessageLayout MessageMemoryPage MessageOverlay MessageText MessageView MessageWords TextRow TextStream HelpMessage",
    "07_Archive": "ArchiveData ArchivePage ArchiveView SaveSlots",
    "08_Menu/Main": "MenuCoordinator MenuScene MenuScreen MenuModel MenuPages SceneRegistry SelectionPage",
    "08_Menu/Item": "InventoryScene ItemPage ItemPresets EquipmentPage ItemView EquipmentView",
    "08_Menu/Skill": "SkillScene SkillConfig SkillPage CastingPage SkillView",
    "08_Menu/Orbment": "BlasticPage BlasticView",
    "08_Menu/Note": "NotePage NoteView",
    "08_Menu/Sight": "SightModel SightPage SightView",
    "08_Menu/MapSystem": "MapBlock MapConfig MapCursor MapPreview MapScreen MapSystem",
    "08_Menu/Shop": "ShopScene ShopService ShopView",
    "09_Effects": "BrokenScreen EffectView PresentationState ScreenEffects Unravel RmxpAnimationData RmxpAnimationPlayer TransitionRenderer",
    "10_Support/Boot": "Game",
    "10_Support/Audio": "AudioRuntime",
    "10_Support/Cache": "RmxpCache",
    "10_Support/Persistence": "SaveCodec SaveGraph SavePreparation SaveLoadProgress SaveService FileStore History MapSnapshot",
    "10_Support/Scripting": "ScriptRuntime ScriptSemantics ScriptStateBridge ScriptQueryProof ScriptErrorLogger RubyRegexValues ValueExtensions ScriptPaths ProgramDocumentation",
    "10_Support/Utilities": "DecimalInteger Keyboard MoviePlayer Utils",
    "11_Development": "ActorTools AnimationLab EventFixture EventTestHUD DebugPage MovementFixture MovementTools PresentationTools ScreenTools StateTools TestTools",
}
EDITOR_GROUPS = {
    "00_Plugin": "Editor_Plugin Editor_Panel",
    "01_Documents": "Editor_Documents Editor_ProjectTransaction Editor_CapacityOps",
    "02_Map": "Editor_MapCanvas Editor_MapLocationPicker Editor_MapOps Editor_TilesetEditor Editor_TilesetOps Editor_TilesetSourcesDialog Editor_TileGraphicDialog",
    "03_Event": "Editor_EventScript Editor_CommandColors Editor_CommandDialog Editor_CommandList Editor_Commands Editor_EventPageForm Editor_RouteDialog Editor_RouteForm Editor_ScriptAdapter",
    "04_Database": "Editor_DatabaseDialog Editor_DatabaseForm Editor_DatabaseSchema Editor_LearningsEditor Editor_NamesEditor Editor_SetDialog Editor_TableDialog Editor_ValueForm Editor_AnimationCanvas Editor_AnimationEditor",
    "05_Assets": "Editor_AssetDialog Editor_AssetPreview Editor_AudioBrowser Editor_AudioDialog Editor_AudioPreview",
    "06_Scripts": "Editor_ScriptCoverage Editor_ScriptDialog Editor_ScriptWorkspace",
    "07_Common": "Editor_Presentation",
}


def paths(groups):
    return {name + ".gd": group + "/" + name + ".gd" for group, names in groups.items() for name in names.split()}


RUNTIME = paths(RUNTIME_GROUPS)
EDITOR = paths(EDITOR_GROUPS)
SCENES = {name: "05_Title/" + name for name in ("Title.tscn", "Gameover.tscn")}
SCENES.update({"Game.tscn": "03_Map/Game.tscn", "Menu.tscn": "08_Menu/Menu.tscn"})


def registry_text():
    rows = ["extends RefCounted", "## Generated by tools/script_layout.py; maps stable filenames to grouped paths.", "## Used by dynamic scene/tool navigation; ordinary imports use explicit paths.", "const RUNTIME := {"]
    for filename, relative in sorted(RUNTIME.items()):
        rows.append(f'\t"{filename}": "res://runtime/scripts/{relative}",')
    for filename, relative in sorted(legacy_runtime_aliases().items()):
        rows.append(f'\t"{filename}": "res://runtime/scripts/{relative}",')
    rows += ["}", "", "", "static func runtime(filename: String) -> String:", '\treturn RUNTIME.get(filename, "")', ""]
    return with_header(RUNTIME_ROOT + "/10_Support/Scripting/ScriptPaths.gd", "\n".join(rows))


def legacy_runtime_aliases():
    record = REPO / "tools/script_renames_v059.json"
    if not record.exists():
        return {}
    return {Path(row["old"]).name: row["new"].removeprefix(RUNTIME_ROOT + "/")
            for row in json.loads(record.read_text("utf-8"))["files"]
            if row["old"].startswith(RUNTIME_ROOT + "/")}


def apply():
    roots = [(RUNTIME_ROOT, RUNTIME), (EDITOR_ROOT, EDITOR)]
    pending = any((REPO / root / name).exists() for root, mapping in roots for name in mapping)
    pending = pending or any((REPO / "templates/runtime/scenes" / name).exists() for name in SCENES)
    if not pending:
        write_index()
        print("Layout already grouped; refreshed index without rewriting source or legacy aliases.")
        return
    for root, mapping in [(RUNTIME_ROOT, RUNTIME), (EDITOR_ROOT, EDITOR)]:
        actual = {p.name for p in (REPO / root).rglob("*.gd")}
        assert actual == set(mapping), (root, actual - set(mapping), set(mapping) - actual)
        for filename, relative in mapping.items():
            source, target = REPO / root / filename, REPO / root / relative
            assert target.resolve().is_relative_to(REPO)
            if source.exists():
                assert not target.exists(), target
                target.parent.mkdir(parents=True, exist_ok=True)
                source.rename(target)
                if source.with_suffix(".gd.uid").exists():
                    source.with_suffix(".gd.uid").rename(target.with_suffix(".gd.uid"))
    for name, relative in SCENES.items():
        source, target = REPO / "templates/runtime/scenes" / name, REPO / "templates/runtime/scenes" / relative
        if source.exists():
            target.parent.mkdir(parents=True, exist_ok=True)
            source.rename(target)
    replacements = {}
    for prefix, mapping in [(RUNTIME_ROOT, RUNTIME), ("runtime/scripts", RUNTIME), (EDITOR_ROOT, EDITOR), ("addons/rgm_editor", EDITOR)]:
        for name, relative in mapping.items():
            replacements[prefix + "/" + name] = prefix + "/" + relative
    for prefix in ("scenes", "templates/runtime/scenes"):
        for name, relative in SCENES.items():
            replacements[prefix + "/" + name] = prefix + "/" + relative
    roots = [REPO / part for part in ("scripts", "templates", "tests")]
    files = [p for root in roots for p in root.rglob("*") if p.is_file() and p.suffix in (".gd", ".py", ".ps1", ".tscn", ".cfg")]
    files += [REPO / "AGENTS.md", REPO / "README.md", REPO / "tools/sync_save_preparation.py"]
    for file in files:
        source = file.read_text("utf-8-sig")
        for old, new in replacements.items():
            source = source.replace(old, new)
        mapping = EDITOR if file.is_relative_to(REPO / EDITOR_ROOT) else RUNTIME
        base = EDITOR_ROOT if mapping is EDITOR else RUNTIME_ROOT
        # Relative imports in templates must remain valid in both source and export.
        def relative_import(match):
            name = match[2]
            if name not in mapping:
                return match[0]
            if file.is_relative_to(REPO / base):
                target = REPO / base / mapping[name]
                relative = posixpath.relpath(target.as_posix(), file.parent.as_posix())
            else:
                relative = "res://runtime/scripts/" + mapping[name]
            return match[1] + relative + match[3]
        source = re.sub(r'((?:preload|load)\(")([^"/]+\.gd)("\))', relative_import, source)
        source = re.sub(r'(^extends ")([^"/]+\.gd)(")', relative_import, source, flags=re.M)
        if file.suffix == ".cfg" and file.name == "plugin.cfg":
            source = source.replace('script="Editor_Plugin.gd"', 'script="00_Plugin/Editor_Plugin.gd"')
        file.write_text(source, "utf-8")
    write_index()
    print(f"Relocated {len(RUNTIME)} runtime scripts, {len(EDITOR)} editor scripts and {len(SCENES)} scenes.")


def write_index():
    registry = REPO / RUNTIME_ROOT / "10_Support/Scripting/ScriptPaths.gd"
    registry.write_text(registry_text(), "utf-8")
    manifest = {"version": "0.59", "runtime": RUNTIME, "editor": EDITOR, "scenes": SCENES,
                "legacy_runtime_aliases": legacy_runtime_aliases()}
    (REPO / "templates/runtime/script_layout.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", "utf-8")


def check():
    for root, mapping in [(RUNTIME_ROOT, RUNTIME), (EDITOR_ROOT, EDITOR)]:
        for relative in mapping.values():
            assert (REPO / root / relative).is_file(), relative
        actual = {p.relative_to(REPO / root).as_posix() for p in (REPO / root).rglob("*.gd")}
        assert actual == set(mapping.values()), (root, actual ^ set(mapping.values()))
    manifest = json.loads((REPO / "templates/runtime/script_layout.json").read_text("utf-8"))
    assert manifest["runtime"] == RUNTIME and manifest["editor"] == EDITOR and manifest["scenes"] == SCENES
    assert (REPO / RUNTIME_ROOT / "10_Support/Scripting/ScriptPaths.gd").read_text("utf-8") == registry_text()
    for file in (REPO / RUNTIME_ROOT).rglob("*.gd"):
        source = file.read_text("utf-8")
        assert "res://addons/" not in source and "res://scripts/importer/" not in source, file
    print("Script groups, path registry and runtime dependency boundary: PASSED")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--refresh-index", action="store_true")
    args = parser.parse_args()
    if args.apply:
        apply()
    if args.check:
        check()
    if args.refresh_index:
        write_index()
