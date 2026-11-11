"""Source/configuration contract for the Android-only product."""
import configparser
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent.parent

class MobileOnlyTest(unittest.TestCase):
    def test_only_android_export_is_available(self):
        config = configparser.ConfigParser(interpolation=None)
        config.read(ROOT / "export_presets.cfg", encoding="utf-8")
        self.assertEqual(config.sections(), ["preset.0", "preset.0.options"])
        self.assertEqual(config["preset.0"]["platform"], '\"Android\"')
        self.assertEqual(config["preset.0.options"]["architectures/arm64-v8a"], "true")
        self.assertIn("tests/*", config["preset.0"]["exclude_filter"])
        self.assertIn("ci/*", config["preset.0"]["exclude_filter"])

    def test_no_desktop_product_entrypoint(self):
        self.assertFalse((ROOT / ".github/workflows/windows.yml").exists())
        project = (ROOT / "project.godot").read_text(encoding="utf-8")
        self.assertNotIn("renderer_benchmark", project)
        self.assertNotIn("shared_source_ui", project)
        self.assertIn('run/main_scene="res://main.tscn"', project)
        policy = (ROOT / "scripts/source_board_camera_policy.gd").read_text(encoding="utf-8")
        self.assertNotIn("config.unity_camera", policy)
        self.assertNotIn("shared_source_ui", policy)

    def test_android_regression_targets_exist(self):
        workflow = (ROOT / ".github/workflows/android.yml").read_text(encoding="utf-8")
        targets = re.findall(r"\b[\w]+_test\.gd\b", workflow)
        self.assertGreater(len(targets), 30)
        for target in targets:
            self.assertTrue((ROOT / "tests" / target).is_file(), target)

    def test_runtime_script_references_resolve(self):
        for folder in ("scripts", "original_board/scripts", "source_rope", "addons"):
            for source in (ROOT / folder).rglob("*.gd"):
                text = source.read_text(encoding="utf-8")
                for target in re.findall(r"(?:preload|load)\([\"']res://([^\"']+\.gd)[\"']\)", text):
                    self.assertTrue((ROOT / target).is_file(), f"{source.relative_to(ROOT)} -> {target}")

    def test_required_phone_ui_and_fixed_overlay_remain(self):
        for name in ("source_phone_layout_controller.gd", "native_phone_hand.gd",
                     "native_phone_board_actors.gd", "native_phone_mana_renderer.gd",
                     "native_phone_deck.gd", "native_phone_name_banner.gd"):
            self.assertTrue((ROOT / "scripts" / name).is_file(), name)
        game = (ROOT / "scripts/game.gd").read_text(encoding="utf-8")
        self.assertRegex(game, r"fixed_layer\s*=\s*CanvasLayer\.new\(\)")
        self.assertIn("source_phone_name_banners", game)

if __name__ == "__main__":
    unittest.main()
