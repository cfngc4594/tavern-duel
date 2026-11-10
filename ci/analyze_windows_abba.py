"""Validate and summarize four privacy-mode Windows logs in R,C,C,R order.

Usage: python ci/analyze_windows_abba.py R1.log C1.log C2.log R2.log --output report.json
No performance results are emitted until environment and gameplay checks pass.
Exit status, thermal conditions and absence of competing workloads require
external verification. Event timing differences are reported, not called equal.
"""
import argparse
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tests"))
from verify_renderer_benchmark import check, validate


LIMITS = (16.667, 33.333, 50)
STATES = ("health", "hand", "units", "busy")
TIMINGS = ("time", "frame")


def summarize(values):
    check(values and all(type(v) in (int, float) and math.isfinite(v) and v >= 0 for v in values), "invalid timing samples")
    ordered = sorted(values)
    n = len(values)
    result = {"count": n, "mean": sum(values) / n,
              "p95": ordered[int(n * .95)], "p99": ordered[int(n * .99)], "max": ordered[-1]}
    for limit in LIMITS:
        count = sum(v > limit for v in values)
        result[f"over_{limit:g}_ms_count"] = count
        result[f"over_{limit:g}_ms_pct"] = 100 * count / n
    return result


def phase_key(phase):
    return f"{phase['phase']}/round_{phase['round']}"


def group_key(phase):
    name = phase["phase"]
    if name in ("archer_battlecry", "archer_recovery_idle"):
        return name + ("/first_process_use" if phase["round"] == 0 else "/warm_repeated")
    context = phase["context"]
    if context.get("suite") == "battlecry_stress":
        # Keep each case and repetition separate, even in arm-level pooling.
        return phase_key(phase)
    return name


def normal_trace(trace):
    check(isinstance(trace, list) and trace, "empty normal action trace")
    for event in trace:
        check(isinstance(event, dict) and "event" in event, "invalid action trace event")
        for key in TIMINGS:
            check(type(event.get(key)) in (int, float) and math.isfinite(event[key]), f"missing event {key}")
    offsets = {key: [event[key] - trace[0][key] for event in trace] for key in TIMINGS}
    for values in offsets.values():
        check(all(a <= b for a, b in zip(values, values[1:])), "nonmonotonic event trace")
    return {"events": [{k: v for k, v in event.items() if k not in TIMINGS} for event in trace],
            "relative_offsets": offsets, "raw": trace}


def load(path, candidate):
    env, outcomes, _ = validate(path)
    records = {}
    for line in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        prefix, _, payload = line.partition(" ")
        if prefix in ("WINDOWS_SETUP", "RUNNER_MODE", "MONITOR_PHASE", "WINDOWS_ACTIONS_PASS", "WINDOWS_STRESS_PASS", "BATTLECRY_STRESS_ACTION_PASS"):
            records.setdefault(prefix, []).append(json.loads(payload))
    for field in ("source_profiling", "pipeline_profiling", "native_profiler", "capture_run"):
        check(env.get(field) is False, f"{path}: {field} must be explicitly false")
    check(env.get("privacy_mask_active") is True, f"{path}: privacy mask must be active")
    check(env.get("defer_highlight_arrays") is candidate, f"{path}: wrong ABBA arm")
    check(env.get("os") == "Windows" and env.get("hardware_gpu_candidate") is True and env.get("headless") is False, f"{path}: expected rendered Windows hardware run")
    check(env.get("debug_build") is False and env.get("editor") is False, f"{path}: expected standalone Release build")
    check(len(records.get("WINDOWS_SETUP", [])) == 1, f"{path}: missing or duplicate WINDOWS_SETUP")
    check(len(records.get("RUNNER_MODE", [])) == 1, f"{path}: missing or duplicate RUNNER_MODE")
    setup = records["WINDOWS_SETUP"][0]
    for key in ("gpu", "method", "size", "phone", "board_variant", "vsync"):
        check(key in setup, f"{path}: setup {key} missing")
    check(setup["gpu"] == env["adapter"] and setup["method"] == env["rendering_method"], "setup/environment renderer mismatch")
    check(setup["vsync"] == 0 and setup["phone"] is False, "expected uncapped desktop setup")
    phases = records["MONITOR_PHASE"]
    for phase in phases:
        check(phase["measurement_scope"] == env["measurement_scope"], "phase measurement scope mismatch")
        for key in STATES:
            check(key in phase, f"phase gameplay state {key} missing")
    traces = {prefix: [normal_trace(trace) for trace in records.get(prefix, [])]
              for prefix in ("WINDOWS_ACTIONS_PASS", "WINDOWS_STRESS_PASS")}
    return {"path": str(path), "arm": "candidate" if candidate else "reference", "environment": env,
            "setup": setup, "runner": records["RUNNER_MODE"][0], "phases": phases,
            "outcomes": outcomes, "traces": traces,
            "stress_actions": records.get("BATTLECRY_STRESS_ACTION_PASS", [])}


def normalized_engine_args(args):
    """Only the output log destination may differ; keep paths and timing flags."""
    check(isinstance(args, list) and all(isinstance(arg, str) for arg in args), "engine_args must be a string list")
    normalized = []
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "--log-file":
            check(index + 1 < len(args) and args[index + 1] and not args[index + 1].startswith("--"), "missing --log-file value")
            normalized.append("--log-file=<run-log>")
            index += 2
        elif arg.startswith("--log-file="):
            check(bool(arg.partition("=")[2]), "missing --log-file value")
            normalized.append("--log-file=<run-log>")
            index += 1
        else:
            normalized.append(arg)
            index += 1
    return normalized


def equivalent(runs):
    baseline = runs[0]
    differences = []
    ignored = {"engine_args", "user_args", "defer_highlight_arrays"}
    comparable = lambda run: {k: v for k, v in run["environment"].items() if k not in ignored}
    for index, run in enumerate(runs[1:], 1):
        check(comparable(run) == comparable(baseline), f"run {index}: environment/build/device/workload differs")
        check(normalized_engine_args(run["environment"]["engine_args"]) == normalized_engine_args(baseline["environment"]["engine_args"]),
              f"run {index}: engine arguments differ beyond log destination")
        check(run["setup"] == baseline["setup"] and run["runner"] == baseline["runner"], f"run {index}: setup or runner differs")
        # Explicit flags may differ only for the candidate toggle.
        flags = lambda r: [v for v in r["environment"]["user_args"] if v not in ("--defer-highlight-arrays", "--no-defer-highlight-arrays")]
        check(flags(run) == flags(baseline), f"run {index}: other user arguments differ")
        check(run["outcomes"] == baseline["outcomes"], f"run {index}: deterministic stress outcomes differ")
        check([phase_key(p) for p in run["phases"]] == [phase_key(p) for p in baseline["phases"]], "phase identities differ")
        for phase, original in zip(run["phases"], baseline["phases"]):
            check({k: phase[k] for k in STATES} == {k: original[k] for k in STATES}, f"run {index}: state differs at {phase_key(phase)}")
        for prefix in run["traces"]:
            check(len(run["traces"][prefix]) == len(baseline["traces"][prefix]), "normal trace counts differ")
            for ordinal, (trace, original) in enumerate(zip(run["traces"][prefix], baseline["traces"][prefix])):
                check(trace["events"] == original["events"], f"run {index}: {prefix} event order/content differs at {ordinal}")
                if trace["relative_offsets"] != original["relative_offsets"]:
                    differences.append({"run": index, "reference_run": 0, "record": prefix, "ordinal": ordinal,
                                        "reference_offsets": original["relative_offsets"], "run_offsets": trace["relative_offsets"]})
        for ordinal, (action, original) in enumerate(zip(run["stress_actions"], baseline["stress_actions"])):
            if action["outcome"]["event_frame_offsets"] != original["outcome"]["event_frame_offsets"]:
                differences.append({"run": index, "reference_run": 0, "record": "BATTLECRY_STRESS_ACTION_PASS", "ordinal": ordinal,
                                    "reference_offsets": original["outcome"]["event_frame_offsets"], "run_offsets": action["outcome"]["event_frame_offsets"]})
    return {"gameplay_state_and_event_order_equal": True, "event_timing_equal": not differences,
            "event_timing_differences": differences}


def pools(runs, grouped=False):
    samples = {}
    for run in runs:
        for phase in run["phases"]:
            key = group_key(phase) if grouped else phase_key(phase)
            samples.setdefault(key, []).extend(phase["raw_samples"]["frame_ms"])
    return {key: summarize(values) for key, values in samples.items()}


def compare(reference, candidate):
    result = {}
    for key, ref in reference.items():
        cand = candidate[key]
        metrics = {}
        for name in ("mean", "p95", "p99", "max") + tuple(f"over_{v:g}_ms_pct" for v in LIMITS):
            delta = cand[name] - ref[name]
            metrics[name] = {"reference": ref[name], "candidate": cand[name], "candidate_minus_reference": delta,
                             "relative_change_pct": 100 * delta / ref[name] if ref[name] else None,
                             "regression": delta > 0}
        result[key] = {"reference_count": ref["count"], "candidate_count": cand["count"], "metrics": metrics}
    return result


def all_phases(runs):
    return {"all_phases": summarize([value for run in runs for phase in run["phases"] for value in phase["raw_samples"]["frame_ms"]])}


def analyze(paths):
    runs = [load(path, candidate) for path, candidate in zip(paths, (False, True, True, False))]
    evidence = equivalent(runs)
    arms = {arm: {"per_phase": pools([r for r in runs if r["arm"] == arm]),
                  "grouped": pools([r for r in runs if r["arm"] == arm], True),
                  "all_phases": all_phases([r for r in runs if r["arm"] == arm])} for arm in ("reference", "candidate")}
    paired = []
    for reference, candidate, order in ((0, 1, "reference_then_candidate"), (3, 2, "candidate_then_reference")):
        paired.append({"order": order, "reference_run": reference, "candidate_run": candidate,
                       "per_phase": compare(pools([runs[reference]]), pools([runs[candidate]])),
                       "grouped": compare(pools([runs[reference]], True), pools([runs[candidate]], True)),
                       "all_phases": compare(all_phases([runs[reference]]), all_phases([runs[candidate]]))})
    reports = []
    for run in runs:
        reports.append({k: run[k] for k in ("path", "arm", "environment", "setup", "runner", "traces", "stress_actions")})
        reports[-1]["phases"] = [{"key": phase_key(p), "phase": p["phase"], "round": p["round"], "context": p["context"],
                                  "state": {k: p[k] for k in STATES}, "frame_ms": summarize(p["raw_samples"]["frame_ms"]),
                                  "game_process_ms": summarize(p["raw_samples"]["game_process_ms"]), "action_usec": p["action_usec"]} for p in run["phases"]]
        reports[-1]["all_phases"] = all_phases([run])["all_phases"]
    return {"schema_version": 1, "order": "R,C,C,R", "equivalence": evidence, "runs": reports,
            "pooled_arms": arms, "pooled_comparison": {key: compare(arms["reference"][key], arms["candidate"][key]) for key in ("per_phase", "grouped", "all_phases")},
            "paired_comparisons": paired,
            "limitations": ["Privacy-mask measurements only; not unobstructed visible-game FPS.",
                            "No stutter-free claim; all measured regressions and threshold exceedances are retained.",
                            "Percentiles use sorted[floor(n*p)]; arm pools concatenate samples, never average percentiles.",
                            "First use means first action in a process, not a cleared shader cache.",
                            "Event timing differences are retained; gameplay equivalence does not assert timing equality.",
                            "Engine argument comparison exempts only --log-file destinations. Godot may consume recognized arguments, leaving engine_args empty; effective runtime settings are not all exposed, so verify the launch commands externally.",
                            "Verify process exit statuses, serial execution and external system conditions separately."]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("logs", nargs=4, type=Path, metavar="LOG")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    check(args.output.resolve() not in [path.resolve() for path in args.logs], "output must not overwrite an input log")
    report = analyze(args.logs)
    args.output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    print(f"WINDOWS_ABBA_ANALYSIS_PASS {args.output}")


if __name__ == "__main__":
    main()
