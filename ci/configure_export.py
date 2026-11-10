from pathlib import Path
import os
import configparser
from renderer_policy import validate_project_renderer
validate_project_renderer(Path("project.godot").read_text(encoding="utf-8"))
privacy_test = os.environ.get("PRIVACY_TEST", "0") == "1"
if privacy_test:
    privacy_config=configparser.ConfigParser(interpolation=None)
    privacy_config.optionxform=str
    privacy_config.read_string('[root]\n'+Path('project.godot').read_text(encoding='utf-8'))
    autoloads=list(privacy_config['autoload'].items())
    assert autoloads and autoloads[0]==('PrivacyTestGuard','"*res://scripts/privacy_test_guard.gd"'), 'Privacy guard must be first'
    assert privacy_config['application']['boot_splash/show_image.privacy_test']=='false'
    assert privacy_config['application']['boot_splash/bg_color.privacy_test']=='Color(0, 0, 0, 1)'
    assert privacy_config['rendering']['environment/defaults/default_clear_color.privacy_test']=='Color(0, 0, 0, 1)'
p=Path("export_presets.cfg")
t=p.read_text(encoding="utf-8")
lines=[]
in_android=False
for line in t.splitlines():
    if line.startswith("[preset."):
        in_android=line.startswith("[preset.0]") or line.startswith("[preset.0.options]")
    if not in_android:
        lines.append(line)
        continue
    if line.startswith("launcher_icons/") and '"res://assets/privacy_test/black.png"' in line:
        continue
    if line.startswith("custom_features="):
        line='custom_features="android_playtest'+(',privacy_test' if privacy_test else '')+'"'
    if line.startswith("custom_template/debug="):
        line='custom_template/debug="'+str(Path.home()/".local/share/godot/export_templates/4.7.1.stable/android_debug.apk")+'"'
    elif line.startswith("custom_template/release="):
        line='custom_template/release=""'
    elif line.startswith("version/code="):
        line="version/code="+str(37415+int(os.environ.get("GITHUB_RUN_NUMBER","1")))
    elif line.startswith("version/name="):
        line='version/name="37.4.15-child-ci'+os.environ.get("GITHUB_RUN_NUMBER","1")+'"'
    elif line.startswith("package/unique_name="):
        # Disposable CI keys cannot update an APK signed by a previous run.
        # Use a distinct application ID so testing never requires deleting data.
        line='package/unique_name="org.dot.tavernduel.childcandidate.ci'+os.environ.get("GITHUB_RUN_NUMBER","1")+('.privacy' if privacy_test else '')+'"'
    elif line.startswith("package/name="):
        line='package/name="'+('Render Test ' if privacy_test else 'Tavern Duel Test CI')+os.environ.get("GITHUB_RUN_NUMBER","1")+'"'
        if privacy_test:
            lines.extend(['launcher_icons/main_192x192="res://assets/privacy_test/black.png"', 'launcher_icons/adaptive_foreground_432x432="res://assets/privacy_test/black.png"', 'launcher_icons/adaptive_background_432x432="res://assets/privacy_test/black.png"'])
    elif line.startswith("export_path="):
        line='export_path="build/TavernDuel-latest-candidate.apk"'
    lines.append(line)
p.write_text("\n".join(lines)+"\n",encoding="utf-8")
settings=Path.home()/".config/godot/editor_settings-4.7.tres"
settings.parent.mkdir(parents=True,exist_ok=True)
settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/android_sdk_path = "'+os.environ["ANDROID_HOME"]+'"\nexport/android/java_sdk_path = "'+os.environ["JAVA_HOME"]+'"\n',encoding="utf-8")
