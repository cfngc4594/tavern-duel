"""Synthetic, reproducible ABBA analyzer checks; no engine or real logs needed."""
import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

from verify_renderer_benchmark_test import fixture, add_load_instrumentation

SPEC = importlib.util.spec_from_file_location(
    "analyze_windows_abba", Path(__file__).resolve().parents[1] / "ci" / "analyze_windows_abba.py")
abba = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(abba)


def records(candidate):
    rows = fixture(stress_only=False)
    env = rows[0][1]
    env.update(source_profiling=False, pipeline_profiling=False, native_profiler=False,
               capture_run=False, privacy_mask_active=True, defer_highlight_arrays=candidate,
               os="Windows", hardware_gpu_candidate=True, headless=False,
               debug_build=False, editor=False, adapter="Synthetic GPU",
               rendering_method="mobile", measurement_scope="rendered_device_privacy_mask",
               engine={"version": "synthetic-release"}, engine_args=[],
               user_args=["--defer-highlight-arrays" if candidate else "--no-defer-highlight-arrays"])
    for prefix, row in rows:
        if prefix == "MONITOR_PHASE":
            row.update(health=[30, 30], hand=5, units=2, busy=False,
                       measurement_scope=env["measurement_scope"])
        elif prefix == "WINDOWS_ACTIONS_PASS":
            row.extend([{"event": "play", "frame": 100, "time": 1.0},
                        {"event": "damage", "frame": 110, "time": 1.5}])
    rows.extend([
        ("WINDOWS_SETUP", {"gpu": env["adapter"], "method": "mobile", "size": "(1280, 720)",
                           "phone": False, "board_variant": "synthetic", "vsync": 0}),
        ("RUNNER_MODE", {"debug_build": False, "editor": False, "version": env["engine"]}),
    ])
    return rows


class AnalyzeWindowsABBA(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.paths = [Path(self.directory.name, f"run{i}.log") for i in range(4)]
        self.rows = [records(candidate) for candidate in (False, True, True, False)]
        self.write_logs()

    def write_logs(self):
        for path, rows in zip(self.paths, self.rows):
            path.write_text("\n".join(prefix + " " + json.dumps(row) for prefix, row in rows), encoding="utf-8")

    def load_runs(self):
        return [abba.load(path, candidate) for path, candidate in zip(self.paths, (False, True, True, False))]

    def test_complete_analysis(self):
        report = abba.analyze(self.paths)
        self.assertTrue(report["equivalence"]["gameplay_state_and_event_order_equal"])
        self.assertTrue(report["equivalence"]["event_timing_equal"])
        self.assertEqual(len(report["runs"]), 4)
        self.assertEqual(len(report["paired_comparisons"]), 2)
        self.assertEqual(len(report["runs"][0]["phases"]), 24)
        self.assertEqual(report["pooled_arms"]["reference"]["all_phases"]["all_phases"]["count"],
                         2 * report["runs"][0]["all_phases"]["count"])

    def test_board_bundle_boot_memory_and_candidate_isolation(self):
        for index, candidate in enumerate((False, True, True, False)):
            self.rows[index] = add_load_instrumentation(records(False))
            env = self.rows[index][0][1]
            env.update(board_source_bundle=candidate, user_args=["--board-source-bundle" if candidate else "--no-board-source-bundle"])
            for prefix, phase in self.rows[index]:
                if prefix == "MONITOR_PHASE":
                    phase["board_source_store"] = {"enabled": candidate, "loads": int(candidate), "json_hits": 2 if candidate else 0, "image_hits": 2 if candidate else 0, "misses": 0, "error": "", "generation": "fixture" if candidate else "", "raw_json_reads": 0, "raw_image_reads": 0}
        self.write_logs()
        report = abba.analyze(self.paths, "board_source_bundle")
        self.assertEqual(report["candidate_field"], "board_source_bundle")
        self.assertEqual(report["runs"][0]["load_burden"]["boot_wall_ms"]["mean"], 3.1)
        self.assertIn("memory_raw_samples", report["runs"][0]["phases"][0])
        self.assertEqual(report["pooled_arms"]["candidate"]["load_burden"]["boot_frame_intervals"]["count"], 4)
        self.rows[1][0][1]["defer_highlight_arrays"] = True
        self.write_logs()
        with self.assertRaisesRegex(ValueError, "highlight candidate off"):
            abba.analyze(self.paths, "board_source_bundle")
        self.rows[1][0][1]["defer_highlight_arrays"] = False
        next(row for prefix, row in self.rows[1] if prefix == "MONITOR_PHASE")["board_source_store"]["loads"] = 0
        self.write_logs()
        with self.assertRaisesRegex(ValueError, "candidate bundle was not successfully used"):
            abba.analyze(self.paths, "board_source_bundle")

    def test_rejects_equivalence_corruption(self):
        original = self.load_runs()
        for mutation in ("state", "event", "setup", "environment", "stress"):
            with self.subTest(mutation=mutation):
                runs = copy.deepcopy(original)
                if mutation == "state":
                    runs[1]["phases"][0]["hand"] += 1
                elif mutation == "event":
                    runs[1]["traces"]["WINDOWS_ACTIONS_PASS"][0]["events"][0]["event"] = "corrupt"
                elif mutation == "setup":
                    runs[1]["setup"]["size"] = "corrupt"
                elif mutation == "environment":
                    runs[1]["environment"]["adapter"] = "corrupt"
                else:
                    runs[1]["outcomes"][0][1]["busy"] = True
                with self.assertRaises(ValueError):
                    abba.equivalent(runs)

    def test_portrait_source_boot_audit_and_isolation(self):
        for index, candidate in enumerate((False, True, True, False)):
            self.rows[index] = add_load_instrumentation(records(False))
            env = self.rows[index][0][1]
            env.update(board_source_bundle=False, portrait_source_images=candidate,
                       user_args=["--portrait-source-images" if candidate else "--no-portrait-source-images"])
            audit = {"enabled": candidate, "policy_loaded": candidate, "policy_entries": 54 if candidate else 0,
                     "policy_loads": int(candidate), "hits": 54 if candidate else 0, "fallbacks": 0,
                     "bytes": 1000 if candidate else 0, "errors": 0}
            for prefix, row in self.rows[index]:
                if prefix in ("BOOT_LOAD", "MONITOR_PHASE"):
                    row["portrait_source_images"] = dict(audit)
                    row["board_source_store"] = {"enabled": False, "loads": 0, "json_hits": 0, "image_hits": 0, "misses": 0, "generation": "", "error": ""}
        self.write_logs()
        report = abba.analyze(self.paths, "portrait_source_images")
        self.assertEqual(report["candidate_field"], "portrait_source_images")
        for field, value in (("hits", 53), ("fallbacks", 1), ("policy_loads", 2), ("errors", 1)):
            row = next(row for prefix, row in self.rows[1] if prefix == "BOOT_LOAD")
            original = row["portrait_source_images"][field]
            row["portrait_source_images"][field] = value
            self.write_logs()
            with self.assertRaisesRegex(ValueError, "every verified source"):
                abba.analyze(self.paths, "portrait_source_images")
            row["portrait_source_images"][field] = original
        row = next(row for prefix, row in self.rows[1] if prefix == "MONITOR_PHASE")
        row["portrait_source_images"]["bytes"] += 1
        self.write_logs()
        with self.assertRaisesRegex(ValueError, "moved after initial boot"):
            abba.analyze(self.paths, "portrait_source_images")
        row["portrait_source_images"]["bytes"] -= 1
        self.rows[1][0][1]["user_args"].append("--startup-timing")
        self.write_logs()
        with self.assertRaisesRegex(ValueError, "disable startup diagnostics"):
            abba.analyze(self.paths, "portrait_source_images")
        self.rows[1][0][1]["user_args"].pop()
        self.rows[1][0][1]["user_args"].append("--portrait-source-policy=external.json")
        self.write_logs()
        with self.assertRaisesRegex(ValueError, "use its exported policy"):
            abba.analyze(self.paths, "portrait_source_images")

    def test_load_rejects_instrumentation_privacy_and_wrong_arm(self):
        for field in ("source_profiling", "pipeline_profiling", "native_profiler", "capture_run",
                      "privacy_mask_active", "defer_highlight_arrays"):
            with self.subTest(field=field):
                self.rows[1] = records(True)
                env = self.rows[1][0][1]
                env[field] = not env[field]
                self.write_logs()
                with self.assertRaises(ValueError):
                    abba.load(self.paths[1], True)

    def test_incomplete_log_rejected_by_verifier(self):
        self.rows[1] = [(prefix, row) for prefix, row in self.rows[1] if prefix != "BATTLECRY_STRESS_PASS"]
        self.write_logs()
        with self.assertRaises(ValueError):
            abba.analyze(self.paths)

    def test_engine_argument_changes_rejected_except_log_destination(self):
        runs = self.load_runs()
        for index, run in enumerate(runs):
            run["environment"]["engine_args"] = ["--max-fps", "0", "--log-file", f"run{index}.log"]
        self.assertTrue(abba.equivalent(runs)["gameplay_state_and_event_order_equal"])
        runs[1]["environment"]["engine_args"] = ["--max-fps", "0", "--log-file=other.log"]
        self.assertTrue(abba.equivalent(runs)["gameplay_state_and_event_order_equal"])
        for option in ("--max-fps", "--frame-delay", "--time-scale", "--path"):
            with self.subTest(option=option):
                changed = copy.deepcopy(runs)
                changed[1]["environment"]["engine_args"].extend([option, "different"])
                with self.assertRaisesRegex(ValueError, "engine arguments differ"):
                    abba.equivalent(changed)
        for args in (["--log-file"], ["--log-file="], ["--log-file", "--max-fps"], None):
            with self.subTest(args=args), self.assertRaises(ValueError):
                abba.normalized_engine_args(args)

    def test_timing_differences_retained_without_false_gameplay_failure(self):
        runs = self.load_runs()
        runs[1]["traces"]["WINDOWS_ACTIONS_PASS"][0]["relative_offsets"]["frame"][-1] += 1
        result = abba.equivalent(runs)
        self.assertTrue(result["gameplay_state_and_event_order_equal"])
        self.assertFalse(result["event_timing_equal"])
        self.assertEqual(len(result["event_timing_differences"]), 1)
        self.assertEqual(result["event_timing_differences"][0]["run_offsets"]["frame"], [0, 11])

    def test_absolute_frame_origins_are_not_timing_differences(self):
        trace = [{"event": "a", "frame": 10, "time": 1}, {"event": "b", "frame": 20, "time": 2}]
        shifted = [{**event, "frame": event["frame"] + 100, "time": event["time"] + 50} for event in trace]
        self.assertEqual(abba.normal_trace(trace)["relative_offsets"], abba.normal_trace(shifted)["relative_offsets"])

    def test_raw_stats_thresholds_and_invalid_samples(self):
        result = abba.summarize([1, 16.667, 33.333, 50, 51])
        self.assertEqual(result["count"], 5)
        self.assertAlmostEqual(result["mean"], 30.4)
        self.assertEqual((result["p95"], result["p99"], result["max"]), (51, 51, 51))
        self.assertEqual([result[f"over_{v:g}_ms_pct"] for v in abba.LIMITS], [60, 40, 20])
        for invalid in ([], [-1], [float("nan")], [float("inf")], [True]):
            with self.subTest(invalid=invalid), self.assertRaises(ValueError):
                abba.summarize(invalid)

    def test_pools_concatenate_samples_and_comparisons_retain_regressions(self):
        def run(values):
            return {"phases": [{"phase": "idle", "round": 0, "raw_samples": {"frame_ms": values}}]}
        pooled = abba.pools([run([1] * 99), run([100])])
        summary = pooled["idle/round_0"]
        self.assertEqual(summary["count"], 100)
        self.assertEqual(summary["p95"], 1)
        self.assertEqual(summary["p99"], 100)
        compared = abba.compare(abba.pools([run([1] * 100)]), pooled)["idle/round_0"]["metrics"]
        self.assertTrue(compared["p99"]["regression"])
        self.assertFalse(compared["p95"]["regression"])
        self.assertEqual(compared["p99"]["candidate_minus_reference"], 99)


if __name__ == "__main__":
    unittest.main()
