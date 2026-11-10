import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('profiler', Path(__file__).resolve().parents[1] / 'ci/analyze_native_profiler.py')
profiler = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profiler)


class ProfilerLayouts(unittest.TestCase):
    def test_servers(self):
        data = [42, .016, .004, .002, .016, .003, 1, 'Physics', 2, 'step', .002, 5, 7, 4, .001, .003, .0005]
        frame = profiler.decode_servers(data)
        self.assertEqual(frame['functions'][0]['signature_id'], 7)
        self.assertEqual(frame['functions'][0]['internal_seconds'], .0005)
        self.assertEqual(frame['servers'][0]['seconds'], .002)

    def test_visual(self):
        self.assertEqual(profiler.decode_visual([9, 3, 'Frame', 1.2, 2.5])['areas'][0]['gpu_msec'], 2.5)

    def test_matched_spans(self):
        areas = profiler.decode_visual([9, 12, '> A', 1, 2, '> B', 2, 3, '< B', 3, 6, '< A', 5, 9])['areas']
        spans = profiler.visual_spans(areas)
        self.assertEqual(spans[0], {'path': 'A/B', 'cpu_msec': 1, 'gpu_msec': 3})
        self.assertEqual(spans[1]['gpu_msec'], 7)
        self.assertEqual(profiler.visual_spans(areas[:2]), [])

    def test_malformed(self):
        for data in ([], [1, 2, 'bad', 0], [1, 3, 'bad', 1, 2, 'extra']):
            with self.assertRaises(ValueError):
                profiler.decode_visual(data)
        for data in ([], [1, 0, 0, 0, 0, 0, 0, 1, 2], [1, 0, 0, 0, 0, 0, 0, 0, 3]):
            with self.assertRaises(ValueError):
                profiler.decode_servers(data)


if __name__ == '__main__':
    unittest.main()
