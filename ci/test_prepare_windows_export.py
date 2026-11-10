"""Exercise production staging on a tiny synthetic Git fixture, not a source copy."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class WindowsStagingTest(unittest.TestCase):
    def test_forward_plus_staging_with_reviewed_plugin(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'fixture'
            source.mkdir()
            files = {
                'project.godot': (ROOT / 'project.godot').read_text(),
                'main.tscn': '[gd_scene format=3]\n[node name="Game" type="Node"]\n',
                'default_bus_layout.tres': '[gd_resource type="AudioBusLayout" format=3]\n',
                'assets/test.json': '{}',
                'addons/raw_runtime_export/plugin.cfg': '[plugin]\n',
                'addons/raw_runtime_export/plugin.gd': '@tool\nextends EditorPlugin\n',
                'ci/windows_export_presets.cfg': (ROOT / 'ci/windows_export_presets.cfg').read_text(),
                'ci/WINDOWS-README.txt': (ROOT / 'ci/WINDOWS-README.txt').read_text(),
            }
            for name, content in files.items():
                path = source / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
            for command in (['init', '-q'], ['add', '.'], ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Synthetic fixture']):
                subprocess.run(['git', '-C', str(source)] + command, check=True)
            output = Path(directory) / 'output'
            subprocess.run([sys.executable, str(ROOT / 'ci/prepare_windows_export.py'), str(source), str(output)], check=True, capture_output=True, text=True)
            project = (output / 'project/project.godot').read_text()
            self.assertEqual(project.count('[editor_plugins]'), 1)
            self.assertNotIn('run/main_scene.', project)
            manifest = json.loads((output / 'manifest.json').read_text())
            self.assertEqual(manifest['renderer'], 'forward_plus')
            self.assertEqual(manifest['mobile_renderer'], 'forward_plus')
            self.assertIs(manifest['fallback_to_opengl3'], False)
            self.assertEqual(manifest['expected_raw_count'], 1)
            self.assertIs(manifest['source_dirty'], False)


if __name__ == '__main__':
    unittest.main()
