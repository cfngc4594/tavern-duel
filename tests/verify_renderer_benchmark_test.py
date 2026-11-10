"""Positive and corruption tests for the offline benchmark log verifier."""
import copy
import json
import tempfile
import unittest
from pathlib import Path

from verify_renderer_benchmark import validate


def stats(values):
    ordered = sorted(values)
    return {"available": True, "count": len(values), "mean": sum(values)/len(values), "p50": ordered[len(values)//2], "p95": ordered[int(len(values)*.95)], "p99": ordered[int(len(values)*.99)], "max": ordered[-1]}


def fixture(*, stress_only=True, rounds=None, stress_board=None, repetitions=2):
    env = {"stress_only": stress_only, "stress_repetitions": repetitions, "headless": True, "measurement_scope": "headless_logic_only"}
    if rounds is not None:
        env["benchmark_rounds"] = rounds
    if stress_board is not None:
        env["stress_board"] = stress_board
    normal_rounds = 2 if rounds is None else rounds
    records = [("BENCHMARK_ENVIRONMENT", env)]
    phases = []
    actions = []
    sequence = [("startup_settle", -1, None, 180)]
    if not stress_only:
        for index in range(normal_rounds):
            if index:
                sequence.append(("round_reset_settle", index, None, 180))
            sequence.extend((name, index, None, count) for name, count in (("idle", 120), ("play_senjin", 180), ("attack_taunt", 180), ("archer_battlecry", 180), ("archer_recovery_idle", 180)))
    if stress_board:
        sequence.extend((name, normal_rounds, None, count) for name, count in (("stress_setup_settle", 180), ("stress_full_board_idle", 120), ("stress_archer_battlecry", 180), ("stress_recovery_idle", 180)))
    sequence.extend((f"stress_{case}_{part}", index, case, count) for index in range(repetitions) for case in ("full_board_survivor", "full_board_lethal") for part, count in (("setup", 180), ("battlecry", 240), ("recovery", 180)))
    for phase, index, case, count in sequence:
        raw = {"frame_ms": [1., 3., 2.]*(count//3), "game_process_ms": [.1, .3, .2]*(count//3)}
        metrics = {key: stats(values) for key, values in raw.items()}
        for key in ("draw_calls", "render_objects", "primitives", "video_memory_bytes"):
            raw[key] = []
            metrics[key] = {"available": False, "count": 0}
        context = {"suite": "battlecry_stress", "case": case, "repetition": index} if case else {}
        row = {"phase": phase, "round": index, "raw_samples": raw, "metrics": metrics, "frame_ms_trace": raw["frame_ms"].copy(), "frame_start_usec_trace": list(range(count)), "frame_end_usec_trace": list(range(count)), "pipeline_compilations": {"status": {"available": False}}, "context": context, "action_usec": 10}
        records.append(("MONITOR_PHASE", row))
        if phase == "archer_recovery_idle":
            records.append(("WINDOWS_ACTIONS_PASS", []))
        if phase == "stress_recovery_idle":
            records.append(("WINDOWS_STRESS_PASS", []))
        if case and phase.endswith("_battlecry"):
            phases.append(row)
            records.append(("BATTLECRY_STRESS_ACTION_PASS", {"context": context, "outcome": {"events": ["battlecry_damage1"], "event_frame_offsets": [100]}}))
            actions.append({"case": case, "repetition": index, "frame_ms": metrics["frame_ms"], "game_process_ms": metrics["game_process_ms"], "action_usec": 10})
    if not repetitions:
        return records
    pools = {}
    for case in ("full_board_survivor", "full_board_lethal"):
        selected = [row for row in phases if row["context"]["case"] == case]
        pool = {}
        for metric, summary in (("frame_ms", "all_action_frames_ms"), ("game_process_ms", "all_action_game_process_ms")):
            values = [value for row in selected for value in row["raw_samples"][metric]]
            pool[metric+"_trace"] = values
            pool[summary] = stats(values)
        pool["action_usec_trace"] = [10] * repetitions
        pool["synchronous_action_usec"] = stats([10] * repetitions)
        pools[case] = pool
    records.append(("BATTLECRY_STRESS_PASS", {"repetitions_per_case": repetitions, "actions": actions, "pooled": pools}))
    return records


def add_load_instrumentation(records):
    records[0][1]["load_memory_instrumentation"] = 1
    memory = {"static_memory_bytes": 1000, "node_count": 10, "resource_count": 20}
    raw = {"frame_ms": [1., 2.], **{key: [value, value] for key, value in memory.items()}, "video_memory_bytes": []}
    if not records[0][1]["headless"]:
        raw["video_memory_bytes"] = [100, 100]
    boot = {"native_initial_loading_complete": True, "measurement_scope": records[0][1]["measurement_scope"],
            "start_usec": 100, "ready_usec": 3200, "wall_usec": 3100,
            "game_new_usec": 100, "add_child_usec": 100, "synchronous_preparation_usec": 300,
            "frame_start_usec_trace": [100, 1100], "frame_end_usec_trace": [1100, 3100], "raw_samples": raw,
            "metrics": {key: stats(values) if values else {"available": False, "count": 0} for key, values in raw.items()},
            "memory_before": memory, "memory_after": memory}
    records.extend([("BOOT_LOAD", boot), ("STARTUP_PREPARATION", {"wall_usec": 3100})])
    clock = 4000
    for prefix, phase in records:
        if prefix != "MONITOR_PHASE":
            continue
        for key, value in memory.items():
            phase["raw_samples"][key] = [value] * len(phase["raw_samples"]["frame_ms"])
            phase["metrics"][key] = stats(phase["raw_samples"][key])
        phase.update(memory_before=memory, memory_after=memory, board_source_store={"enabled": False})
        phase["frame_start_usec_trace"], phase["frame_end_usec_trace"] = [], []
        for value in phase["raw_samples"]["frame_ms"]:
            phase["frame_start_usec_trace"].append(clock)
            clock += int(value * 1000)
            phase["frame_end_usec_trace"].append(clock)
    return records


class VerifyLogs(unittest.TestCase):
    def run_fixture(self, records):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "test.log")
            path.write_text("\n".join(prefix+" "+json.dumps(data) for prefix, data in records))
            return validate(path)

    def test_valid(self):
        self.assertEqual(self.run_fixture(fixture())[2], 13)

    def test_load_memory_instrumentation(self):
        base = add_load_instrumentation(fixture())
        self.assertEqual(self.run_fixture(base)[2], 13)
        for mutation in ("missing_boot", "missing_memory", "bad_wall", "bad_trace", "not_ready", "shifted_work"):
            with self.subTest(mutation=mutation):
                rows = copy.deepcopy(base)
                boot = next(row for prefix, row in rows if prefix == "BOOT_LOAD")
                if mutation == "missing_boot":
                    rows = [(p, r) for p, r in rows if p != "BOOT_LOAD"]
                elif mutation == "missing_memory":
                    rows[1][1]["raw_samples"]["static_memory_bytes"].pop()
                elif mutation == "bad_wall":
                    boot["wall_usec"] += 1
                elif mutation == "bad_trace":
                    boot["frame_start_usec_trace"][0] += 1
                elif mutation == "not_ready":
                    boot["native_initial_loading_complete"] = False
                else:
                    boot["game_new_usec"] = 5000
                with self.assertRaises(ValueError):
                    self.run_fixture(rows)

    def test_zero_static_tracking_is_unavailable(self):
        rows = add_load_instrumentation(fixture())
        boot = next(row for prefix, row in rows if prefix == "BOOT_LOAD")
        boot["raw_samples"]["static_memory_bytes"] = [0, 0]
        boot["metrics"]["static_memory_bytes"] = {"available": False, "observed_count": 2}
        self.run_fixture(rows)
        boot["metrics"]["static_memory_bytes"]["mean"] = 0
        with self.assertRaises(ValueError):
            self.run_fixture(rows)

    def test_bundle_audit_stays_valid_in_every_phase(self):
        for candidate in (False, True):
            base = fixture()
            base[0][1]["board_source_bundle"] = candidate
            for index, (prefix, phase) in enumerate(base):
                if prefix == "MONITOR_PHASE":
                    phase["board_source_store"] = {"enabled": candidate, "loads": int(candidate),
                        "json_hits": index if candidate else 0, "image_hits": index if candidate else 0,
                        "raw_json_reads": index, "raw_image_reads": index, "misses": 0,
                        "generation": "fixture-generation" if candidate else "", "error": ""}
            self.run_fixture(base)
            changes = [("enabled", not candidate), ("loads", 2), ("json_hits", -1),
                       ("image_hits", -1), ("misses", 1), ("generation", "changed"), ("error", "fallback")]
            if candidate:
                changes += [("generation", ""), ("json_hits", 1), ("image_hits", 1),
                            ("raw_json_reads", 0), ("raw_image_reads", 0)]
            else:
                changes += [("json_hits", 1), ("image_hits", 1)]
            for key, value in changes:
                with self.subTest(candidate=candidate, key=key, value=value):
                    rows = copy.deepcopy(base)
                    last = [phase for prefix, phase in rows if prefix == "MONITOR_PHASE"][-1]
                    last["board_source_store"][key] = value
                    with self.assertRaises(ValueError):
                        self.run_fixture(rows)

    def test_legacy_defaults(self):
        self.assertEqual(self.run_fixture(fixture(stress_only=False, repetitions=0))[2], 12)

    def test_optional_rounds_and_stress_board(self):
        for rounds in (2, 3, 20):
            for stress_only in (False, True):
                for stress_board in (False, True):
                    with self.subTest(rounds=rounds, stress_only=stress_only, stress_board=stress_board):
                        rows = fixture(stress_only=stress_only, rounds=rounds, stress_board=stress_board)
                        rows[0][1]["native_profiler"] = True
                        expected = (1 if stress_only else 6 * rounds) + 4 * stress_board + 12
                        self.assertEqual(self.run_fixture(rows)[2], expected)

    def test_legacy_stress_without_new_suite(self):
        self.assertEqual(self.run_fixture(fixture(stress_only=False, stress_board=True, repetitions=0))[2], 16)

    def test_rejects_optional_corruption(self):
        base = fixture(stress_only=False, rounds=3, stress_board=True)
        for field, invalid in (("benchmark_rounds", (0, 1, 21, True, 3.0, "3")), ("stress_board", (1, "true")), ("native_profiler", (1, "true"))):
            for value in invalid:
                with self.subTest(field=field, value=value):
                    rows = copy.deepcopy(base)
                    rows[0][1][field] = value
                    with self.assertRaises(ValueError):
                        self.run_fixture(rows)
        for prefix in ("WINDOWS_ACTIONS_PASS", "WINDOWS_STRESS_PASS", "BATTLECRY_STRESS_ACTION_PASS"):
            for duplicate in (False, True):
                with self.subTest(prefix=prefix, duplicate=duplicate):
                    rows = copy.deepcopy(base)
                    index = next(i for i, row in enumerate(rows) if row[0] == prefix)
                    if duplicate:
                        rows.append(copy.deepcopy(rows[index]))
                    else:
                        rows.pop(index)
                    with self.assertRaises(ValueError):
                        self.run_fixture(rows)
        for field, value in (("round", 2), ("phase", "stress_archer_battlecry")):
            rows = copy.deepcopy(base)
            next(row for prefix, row in rows if prefix == "MONITOR_PHASE" and row["phase"] == "stress_setup_settle")[field] = value
            with self.assertRaises(ValueError):
                self.run_fixture(rows)
        for field, value in (("suite", "legacy"), ("case", "unknown")):
            rows = copy.deepcopy(base)
            next(row for prefix, row in rows if prefix == "MONITOR_PHASE" and row["phase"] == "stress_full_board_survivor_battlecry")["context"][field] = value
            with self.assertRaises(ValueError):
                self.run_fixture(rows)

    def test_rejects_corruption(self):
        def change(records, field, value):
            records[1][1][field] = value
        mutations = [
            lambda rows: rows.pop(2),
            lambda rows: change(rows, "phase", "duplicate"),
            lambda rows: change(rows, "round", 2),
            lambda rows: rows[1][1]["raw_samples"].pop("game_process_ms"),
            lambda rows: rows[1][1]["metrics"]["frame_ms"].update(p99=999),
            lambda rows: rows[1][1]["metrics"]["draw_calls"].update(mean=0),
            lambda rows: rows[1][1]["pipeline_compilations"]["status"].update(available=True),
            lambda rows: rows[-1][1]["actions"][0].update(case="wrong"),
            lambda rows: rows[-1][1]["pooled"]["full_board_survivor"]["frame_ms_trace"].pop(),
        ]
        for mutate in mutations:
            with self.subTest(mutation=mutate):
                rows = copy.deepcopy(fixture())
                mutate(rows)
                with self.assertRaises((ValueError, KeyError)):
                    self.run_fixture(rows)


if __name__ == "__main__":
    unittest.main()
