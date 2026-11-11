"""Build-time renderer policy checks; these are not runtime GPU measurements."""
import configparser
import json
import struct
import sys
from pathlib import Path

EXPECTED_SETTINGS = {
    "rendering/renderer/rendering_method": "forward_plus",
    "rendering/renderer/rendering_method.mobile": "forward_plus",
    "rendering/rendering_device/fallback_to_opengl3": False,
}


def validate_project_renderer(text):
    config = configparser.ConfigParser(interpolation=None, strict=True)
    config.read_string("[root]\n" + text)
    actual = {}
    for key, expected in EXPECTED_SETTINGS.items():
        section, option = key.split("/", 1)
        raw = config.get(section, option, fallback=None)
        value = raw == "true" if isinstance(expected, bool) and raw in ("true", "false") else raw
        if isinstance(value, str) and value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        if value != expected:
            raise ValueError(f"Renderer policy mismatch: {key}={raw!r}; expected {expected!r}")
        actual[key] = value
    # Additional feature overrides must not select another renderer.
    for option, value in config.items("rendering"):
        if option.startswith("renderer/rendering_method.") and value != '"forward_plus"':
            raise ValueError(f"Conflicting renderer feature override: {option}={value}")
    return actual


def read_packed_renderer_settings(data):
    """Read only policy values from Godot's length-delimited ECFG project.binary."""
    if data[:4] != b"ECFG":
        raise ValueError("Missing Godot ECFG header")
    offset = 4

    def uint32():
        nonlocal offset
        if offset + 4 > len(data):
            raise ValueError("Truncated project.binary")
        value = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        return value

    def blob():
        nonlocal offset
        size = uint32()
        if size > len(data) - offset:
            raise ValueError("Invalid project.binary field size")
        value = data[offset:offset + size]
        offset += size
        return value

    count = uint32()
    if count > len(data) // 8:
        raise ValueError("Invalid project.binary entry count")
    result = {}
    for _ in range(count):
        name = blob().decode("utf-8")
        raw = blob()
        if name not in EXPECTED_SETTINGS:
            continue
        if name in result or len(raw) < 8:
            raise ValueError(f"Duplicate or invalid renderer field: {name}")
        kind, value = struct.unpack_from("<II", raw)
        if kind == 4 and value <= len(raw) - 8:
            result[name] = raw[8:8 + value].decode("utf-8")
        elif kind == 1 and value in (0, 1):
            result[name] = bool(value)
        else:
            raise ValueError(f"Unexpected renderer value type: {name}")
    if offset != len(data):
        raise ValueError("Unexpected trailing project.binary data")
    return result


def validate_packed_renderer(data):
    settings = read_packed_renderer_settings(data)
    # Godot 4.7.1 omits properties equal to their engine defaults when saving
    # project.binary. Base Forward+ is such a default; mobile Forward+ and
    # disabled OpenGL fallback are NOT defaults and must remain explicit.
    effective = dict(settings)
    effective.setdefault("rendering/renderer/rendering_method", "forward_plus")
    if effective != EXPECTED_SETTINGS:
        raise ValueError(f"Packaged renderer policy mismatch: {settings!r}")
    return settings


if __name__ == "__main__":
    settings = validate_project_renderer(Path(sys.argv[1] if len(sys.argv) > 1 else "project.godot").read_text(encoding="utf-8"))
    print("FORWARD_PLUS_POLICY_PASS " + json.dumps(settings, sort_keys=True))
