"""Validate complete renderer/stress logs, not performance or GPU equivalence.

Usage: python3 tests/verify_renderer_benchmark.py build/run.log [build/other.log]
Two logs additionally compare deterministic stress outcomes/event order. Event
frame offsets are reported but excluded: original first-use source timing differs.
"""
import json
import math
import sys
from pathlib import Path


def check(condition, message):
    if not condition:
        raise ValueError(message)


def verify_stats(values, summary, label):
    check(values and all(isinstance(v, (float, int)) and math.isfinite(v) for v in values), f"{label}: nonempty finite samples required")
    check(summary.get("available") and summary["count"] == len(values), f"{label}: sample count differs")
    ordered = sorted(values)
    for key, expected in {"mean": sum(values)/len(values), "p50": ordered[len(values)//2], "p95": ordered[int(len(values)*.95)], "p99": ordered[int(len(values)*.99)], "max": ordered[-1]}.items():
        check(math.isclose(summary[key], expected, rel_tol=1e-10, abs_tol=1e-9), f"{label}/{key} disagrees with raw samples")


def validate(path):
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    check(not any(token in text for token in ("SCRIPT ERROR", "ERROR:", "BENCH_FAIL")), f"{path}: engine or benchmark error")

    def rows(prefix):
        return [json.loads(line[len(prefix) + 1:]) for line in text.splitlines() if line.startswith(prefix + " ")]

    environments = rows("BENCHMARK_ENVIRONMENT")
    check(len(environments) == 1, "exactly one environment record required")
    env = environments[0]
    phases = rows("MONITOR_PHASE")
    repetitions = env["stress_repetitions"]
    rounds = env.get("benchmark_rounds", 2)
    stress_board = env.get("stress_board", False)
    check(type(rounds) is int and 2 <= rounds <= 20, "invalid benchmark round count")
    check(type(stress_board) is bool, "invalid stress-board flag")
    check(type(env.get("native_profiler", False)) is bool, "invalid native-profiler flag")
    check(isinstance(repetitions, int) and (repetitions == 0 or 2 <= repetitions <= 100), "invalid repetition count")
    check(not env["stress_only"] or repetitions > 0, "stress-only has no stress actions")
    expected = [("startup_settle", -1, 180)]
    if not env["stress_only"]:
        for index in range(rounds):
            if index:
                expected.append(("round_reset_settle", index, 180))
            expected.extend((name, index, count) for name, count in [("idle", 120), ("play_senjin", 180), ("attack_taunt", 180), ("archer_battlecry", 180), ("archer_recovery_idle", 180)])
    if stress_board:
        expected.extend((name, rounds, count) for name, count in [("stress_setup_settle", 180), ("stress_full_board_idle", 120), ("stress_archer_battlecry", 180), ("stress_recovery_idle", 180)])
    cases = ("full_board_survivor", "full_board_lethal")
    for index in range(repetitions):
        for case in cases:
            expected.extend((f"stress_{case}_{part}", index, count) for part, count in [("setup", 180), ("battlecry", 240), ("recovery", 180)])
    check([(p["phase"], p["round"], len(p["raw_samples"]["frame_ms"])) for p in phases] == expected, "phase order, identity or frame count differs")
    core = [p for p in phases if p["phase"] in ("idle", "play_senjin", "attack_taunt", "archer_battlecry")]
    check(len(core) == (0 if env["stress_only"] else 4 * rounds), "normal-round core phases changed")
    check(len(rows("WINDOWS_ACTIONS_PASS")) == (0 if env["stress_only"] else rounds), "normal-round validation missing")
    check(len(rows("WINDOWS_STRESS_PASS")) == int(stress_board), "legacy stress-board validation missing or unexpected")
    for phase in phases:
        raw = phase["raw_samples"]
        frames = raw["frame_ms"]
        check(len(raw["game_process_ms"]) == len(frames), "game CPU samples missing")
        check(frames == phase["frame_ms_trace"], "frame order mutated by summary")
        check(len(frames) == len(phase["frame_start_usec_trace"]) == len(phase["frame_end_usec_trace"]), "timestamp trace length differs")
        for name, summary in phase["metrics"].items():
            values = raw[name]
            if not summary["available"]:
                check(not any(k in summary for k in ("mean", "p95", "p99", "max")), "unavailable metric includes a timing")
                continue
            verify_stats(values, summary, name)
        if env["headless"]:
            check(not any(k.endswith("/gpu_ms") for k in phase["metrics"]), "headless GPU timing fabricated")
            check(not phase["pipeline_compilations"]["status"]["available"], "headless pipeline counters should be unavailable")
            check(all(not phase["metrics"][k]["available"] for k in ("draw_calls", "render_objects", "primitives", "video_memory_bytes")), "headless render metric should be unavailable")

    actions = rows("BATTLECRY_STRESS_ACTION_PASS")
    check(len(actions) == 2 * env["stress_repetitions"], "stress actions incomplete")
    check(len(rows("BATTLECRY_STRESS_PASS")) == (1 if env["stress_repetitions"] else 0), "stress completion missing")
    outcomes = []
    stress_phases = [p for p in phases if p["context"].get("suite") == "battlecry_stress" and p["context"].get("case") in cases and p["phase"] == f"stress_{p['context']['case']}_battlecry"]
    check(len(stress_phases) == len(actions), "stress action phase context missing or invalid")
    for action, phase in zip(actions, stress_phases):
        check(action["context"] == phase["context"], "stress action context differs from measured phase")
        outcome = dict(action["outcome"])
        outcome.pop("event_frame_offsets")
        outcomes.append((action["context"], outcome))
        if env["measurement_scope"] == "headless_partial_cpu_visuals":
            check(all(n > 0 for n in action["cpu_visual_evidence"].values()), "CPU visual workload was not observed")
    if repetitions:
        final = rows("BATTLECRY_STRESS_PASS")[0]
        check(final["repetitions_per_case"] == repetitions and len(final["actions"]) == len(actions), "pooled action count differs")
        for row, phase in zip(final["actions"], stress_phases):
            check(row["case"] == phase["context"]["case"] and row["repetition"] == phase["round"], "summary action identity differs")
            for metric in ("frame_ms", "game_process_ms"):
                verify_stats(phase["raw_samples"][metric], row[metric], f"action/{metric}")
            check(row["action_usec"] == phase["action_usec"], "action duration differs")
        for case in cases:
            selected = [p for p in stress_phases if p["context"]["case"] == case]
            pool = final["pooled"][case]
            for metric, key in [("frame_ms", "all_action_frames_ms"), ("game_process_ms", "all_action_game_process_ms")]:
                values = [value for p in selected for value in p["raw_samples"][metric]]
                check(pool[f"{metric}_trace"] == values, "pooled trace differs from action phases")
                verify_stats(values, pool[key], f"pool/{metric}")
            values = [p["action_usec"] for p in selected]
            check(pool["action_usec_trace"] == values, "pooled action duration trace differs")
            verify_stats(values, pool["synchronous_action_usec"], "pool/action_usec")
    return env, outcomes, len(phases)


if __name__ == "__main__":
    check(len(sys.argv) in (2, 3), __doc__)
    first = validate(sys.argv[1])
    if len(sys.argv) == 3:
        second = validate(sys.argv[2])
        check(first[0]["measurement_scope"] == second[0]["measurement_scope"], "cannot compare different workload scopes")
        check(first[1] == second[1], "stress action outcomes or event order differ")
    print(f"RENDERER_BENCHMARK_LOG_PASS phases={first[2]} scope={first[0]['measurement_scope']}")
