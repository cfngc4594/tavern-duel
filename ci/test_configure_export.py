"""Configuration-only fixtures: no source tree copy and no Godot execution."""
import configparser
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "ci/configure_export.py"


class ConfigureExportTest(unittest.TestCase):
    def test_isolated_repeatable_privacy_and_normal_exports(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            (work / "project.godot").write_text((ROOT / "project.godot").read_text())
            (work / "export_presets.cfg").write_text((ROOT / "export_presets.cfg").read_text())
            expected = configparser.ConfigParser(interpolation=None)
            expected.read(ROOT / "export_presets.cfg")
            for privacy in ("1", "1", "0", "0"):
                env = dict(os.environ, HOME=directory, USERPROFILE=directory, ANDROID_HOME="/test/android", JAVA_HOME="/test/java", GITHUB_RUN_NUMBER="42", PRIVACY_TEST=privacy, PYTHONDONTWRITEBYTECODE="1")
                subprocess.run([sys.executable, str(SCRIPT)], cwd=work, env=env, check=True)
                config = configparser.ConfigParser(interpolation=None, strict=True)
                config.read(work / "export_presets.cfg")
                self.assertEqual(dict(config["preset.1"]), dict(expected["preset.1"]))
                self.assertEqual(dict(config["preset.1.options"]), dict(expected["preset.1.options"]))
                self.assertEqual(config["preset.0.options"]["package/unique_name"], '"org.dot.tavernduel.childcandidate.ci42' + ('.privacy' if privacy == '1' else '') + '"')
                self.assertEqual('privacy_test' in config["preset.0"]["custom_features"], privacy == '1')
                self.assertEqual(config.has_option("preset.0.options", "launcher_icons/main_192x192"), privacy == '1')
                self.assertEqual(config["preset.0.options"]["permissions/internet"], "false")
                self.assertEqual(config["preset.0.options"]["user_data_backup/allow"], "false")


if __name__ == "__main__":
    unittest.main()
