"""Small negative tests for the offline benchmark log verifier."""
import copy
import json
import tempfile
import unittest
from pathlib import Path

from verify_renderer_benchmark import validate


def stats(values):
    ordered = sorted(values)
    return {"available": True, "count": len(values), "mean": sum(values)/len(values), "p50": ordered[len(values)//2], "p95": ordered[int(len(values)*.95)], "p99": ordered[int(len(values)*.99)], "max": ordered[-1]}


def fixture():
    env = {"stress_only": True, "stress_repetitions": 2, "headless": True, "measurement_scope": "headless_logic_only"}
    records = [("BENCHMARK_ENVIRONMENT", env)]
    phases = []
    actions = []
    for phase, index, case, count in [("startup_settle", -1, None, 180)] + [(f"stress_{case}_{part}", index, case, count) for index in range(2) for case in ("full_board_survivor", "full_board_lethal") for part, count in (("setup", 180), ("battlecry", 240), ("recovery", 180))]:
        raw = {"frame_ms": [1., 3., 2.]*(count//3), "game_process_ms": [.1, .3, .2]*(count//3)}
        metrics = {key: stats(values) for key, values in raw.items()}
        for key in ("draw_calls", "render_objects", "primitives", "video_memory_bytes"):
            raw[key] = []
            metrics[key] = {"available": False, "count": 0}
        context = {"case": case, "repetition": index}
        row = {"phase": phase, "round": index, "raw_samples": raw, "metrics": metrics, "frame_ms_trace": raw["frame_ms"].copy(), "frame_start_usec_trace": list(range(count)), "frame_end_usec_trace": list(range(count)), "pipeline_compilations": {"status": {"available": False}}, "context": context, "action_usec": 10}
        records.append(("MONITOR_PHASE", row))
        if phase.endswith("_battlecry"):
            phases.append(row)
            records.append(("BATTLECRY_STRESS_ACTION_PASS", {"context": context, "outcome": {"events": ["battlecry_damage1"], "event_frame_offsets": [100]}}))
            actions.append({"case": case, "repetition": index, "frame_ms": metrics["frame_ms"], "game_process_ms": metrics["game_process_ms"], "action_usec": 10})
    pools = {}
    for case in ("full_board_survivor", "full_board_lethal"):
        selected = [row for row in phases if row["context"]["case"] == case]
        pool = {}
        for metric, summary in (("frame_ms", "all_action_frames_ms"), ("game_process_ms", "all_action_game_process_ms")):
            values = [value for row in selected for value in row["raw_samples"][metric]]
            pool[metric+"_trace"] = values
            pool[summary] = stats(values)
        pool["action_usec_trace"] = [10, 10]
        pool["synchronous_action_usec"] = stats([10, 10])
        pools[case] = pool
    records.append(("BATTLECRY_STRESS_PASS", {"repetitions_per_case": 2, "actions": actions, "pooled": pools}))
    return records


class VerifyLogs(unittest.TestCase):
    def run_fixture(self, records):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "test.log")
            path.write_text("\n".join(prefix+" "+json.dumps(data) for prefix, data in records))
            return validate(path)

    def test_valid(self):
        self.assertEqual(self.run_fixture(fixture())[2], 13)

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
