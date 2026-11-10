"""Fast isolated tests for source and actual APK configuration verification."""
import struct
import unittest
from renderer_policy import EXPECTED_SETTINGS, validate_project_renderer, validate_packed_renderer

SOURCE = '''config_version=5
[rendering]
renderer/rendering_method="forward_plus"
renderer/rendering_method.mobile="forward_plus"
rendering_device/fallback_to_opengl3=false
'''


def packed(settings):
    def blob(value):
        return struct.pack("<I", len(value)) + value
    result = b"ECFG" + struct.pack("<I", len(settings))
    for key, value in settings.items():
        if isinstance(value, bool):
            variant = struct.pack("<II", 1, value)
        else:
            encoded = value.encode()
            variant = struct.pack("<II", 4, len(encoded)) + encoded + b"\0" * (-len(encoded) % 4)
        result += blob(key.encode()) + blob(variant)
    return result


class RendererPolicyTest(unittest.TestCase):
    def test_source(self):
        self.assertEqual(validate_project_renderer(SOURCE), EXPECTED_SETTINGS)

    def test_legacy_mobile_rejected(self):
        with self.assertRaises(ValueError):
            validate_project_renderer(SOURCE.replace('method.mobile="forward_plus"', 'method.mobile="gl_compatibility"'))

    def test_fallback_rejected(self):
        with self.assertRaises(ValueError):
            validate_project_renderer(SOURCE.replace("=false", "=true"))

    def test_other_override_rejected(self):
        with self.assertRaises(ValueError):
            validate_project_renderer(SOURCE + 'renderer/rendering_method.android="mobile"\n')

    def test_actual_packed_values(self):
        self.assertEqual(validate_packed_renderer(packed(EXPECTED_SETTINGS)), EXPECTED_SETTINGS)

    def test_omitted_pinned_engine_default(self):
        settings = dict(EXPECTED_SETTINGS)
        del settings["rendering/renderer/rendering_method"]
        self.assertEqual(validate_packed_renderer(packed(settings)), settings)

    def test_legacy_packed_rejected(self):
        settings = dict(EXPECTED_SETTINGS)
        settings["rendering/renderer/rendering_method.mobile"] = "gl_compatibility"
        with self.assertRaises(ValueError):
            validate_packed_renderer(packed(settings))

    def test_missing_packed_setting_rejected(self):
        with self.assertRaises(ValueError):
            validate_packed_renderer(packed({}))

    def test_corrupt_packed_rejected(self):
        for data in (b"", packed(EXPECTED_SETTINGS)[:-1], packed(EXPECTED_SETTINGS) + b"x"):
            with self.assertRaises(ValueError):
                validate_packed_renderer(data)


if __name__ == "__main__":
    unittest.main()
