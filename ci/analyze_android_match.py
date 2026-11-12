"""Summarize an Android match from Godot logcat and SurfaceFlinger TimeStats."""

import argparse
import json
import math
import re
from collections import defaultdict
from itertools import accumulate
from pathlib import Path
from statistics import fmean


MARKER = re.compile(r"\b(MATCH_BENCH_(?:BEGIN|FRAME|EVENT|STAGES|SPIKES|COUNTS|SCENARIO_CASE|FX_CASE|FX_EFFECT|END)|FX_CAPTURE_BENCH|FX_VIEWPORT_PEAK) ")
SURFACE_LAYER = re.compile(r"^\s*layerName\s*=\s*(.+)$", re.MULTILINE)
PRESENT_HISTOGRAM = re.compile(r"^\s*present2present histogram is as below:\s*\n([^\n]+)", re.MULTILINE)
FRAME_COLUMNS = (
    "frame", "frame_usec", "game_usec", "draw_calls", "static_memory",
    "render_memory", "phase", "render_objects", "render_draw_usec",
)
HITCH_THRESHOLDS_MS = (25, 33, 50, 100, 250)


def read_capture(path):
    run = None
    with path.open(encoding="utf-8", errors="replace") as capture:
        for line_number, line in enumerate(capture, 1):
            marker = MARKER.search(line)
            if marker is None:
                continue
            try:
                payload = json.loads(line[marker.end():])
            except json.JSONDecodeError as error:
                raise ValueError(f"line {line_number}: invalid or truncated JSON") from error
            kind = marker[1].removeprefix("MATCH_BENCH_")
            if kind == "BEGIN":
                if run is not None:
                    raise ValueError(f"line {line_number}: expected one match per capture")
                run = {
                    "begin": payload, "frames": [], "events": [], "event_counts": {},
                    "profile_stages": {}, "profile_spikes": {}, "fx_captures": [],
                    "fx_cases": [], "fx_viewports": [], "fx_effects": [], "scenario_cases": [],
                }
            elif run is None:
                raise ValueError(f"line {line_number}: capture starts after MATCH_BENCH_BEGIN")
            elif "end" in run:
                raise ValueError(f"line {line_number}: unexpected benchmark record after MATCH_BENCH_END")
            elif kind == "END":
                run["end"] = payload
            elif kind == "FRAME":
                for row in payload:
                    if not isinstance(row, list) or len(row) not in (7, 8, 9):
                        raise ValueError(f"line {line_number}: unexpected frame row {row!r}")
                    run["frames"].append(dict(zip(FRAME_COLUMNS, row)))
            elif kind == "EVENT":
                run["events"].append(payload)
            elif kind == "FX_CAPTURE_BENCH":
                run["fx_captures"].append(payload)
            elif kind == "FX_VIEWPORT_PEAK":
                run["fx_viewports"].append(payload)
            elif kind == "FX_CASE":
                run["fx_cases"].append(payload)
            elif kind == "SCENARIO_CASE":
                run["scenario_cases"].append(payload)
            elif kind == "FX_EFFECT":
                run["fx_effects"].append(payload)
            elif kind == "COUNTS":
                run["event_counts"].update(payload["events"])
            elif kind == "STAGES":
                run["profile_stages"].setdefault(payload["phase"], {}).update(payload["stages"])
            elif kind == "SPIKES":
                key = (payload["phase"], payload["sample"]["frame"])
                spike = run["profile_spikes"].setdefault(key, payload)
                spike["sample"]["stages"].update(payload["sample"]["stages"])

    if run is None or "end" not in run or not run["frames"]:
        raise ValueError("capture is missing the start, end, or samples of a match")
    if run["frames"][0]["frame"] != 1 or run["end"]["frames"] != len(run["frames"]):
        raise ValueError("capture does not have every frame declared by MATCH_BENCH_END")
    for previous, current in zip(run["frames"], run["frames"][1:]):
        if current["frame"] != previous["frame"] + 1:
            raise ValueError(f"nonconsecutive frame numbers {previous['frame']} → {current['frame']}")
    return run


def distribution(samples, divisor=1):
    ordered = sorted(samples)
    if not ordered:
        return None
    return {
        "samples": len(ordered),
        "mean": round(fmean(ordered) / divisor, 3),
        **{
            f"p{percentile}": round(ordered[math.ceil(len(ordered) * percentile / 100) - 1] / divisor, 3)
            for percentile in (50, 95, 99)
        },
        "max": round(ordered[-1] / divisor, 3),
    }


def phase_summary(frames):
    intervals = [row["frame_usec"] for row in frames if row["frame_usec"] > 0]
    over_budget = {
        str(fps): sum(interval * fps > 1_000_000 for interval in intervals)
        for fps in (60, 120)
    }
    return {
        "frames": len(frames),
        "wall_sec": round(sum(intervals) / 1_000_000, 3),
        "effective_fps": round(1_000_000 / fmean(intervals), 2) if intervals else None,
        "frame_interval_ms": distribution(intervals, 1000),
        "frames_over_budget_by_fps": over_budget,
        "hitch_counts_at_or_above_ms": {
            str(ms): sum(interval >= ms * 1000 for interval in intervals)
            for ms in HITCH_THRESHOLDS_MS
        },
        "game_process_ms": distribution((row["game_usec"] for row in frames if row["game_usec"] > 0), 1000),
        "render_draw_ms": distribution((row["render_draw_usec"] for row in frames if row.get("render_draw_usec", 0) > 0), 1000),
        "draw_calls": distribution(row["draw_calls"] for row in frames if row["draw_calls"] >= 0),
        "render_objects": distribution(row["render_objects"] for row in frames if row.get("render_objects", -1) >= 0),
        "static_memory_mib": distribution((row["static_memory"] for row in frames if row["static_memory"] > 0), 1 << 20),
        "render_memory_mib": distribution((row["render_memory"] for row in frames if row["render_memory"] > 0), 1 << 20),
    }


def summarize(run):
    frames = run["frames"]
    phases = defaultdict(list)
    for row in frames:
        phases[row["phase"]].append(row)
    events_by_frame = defaultdict(list)
    for event in run["events"]:
        events_by_frame[event["frame"]].append(event)
    terminal_phases = {}
    for case in run["fx_cases"]:
        name = case["case"]
        if name in ("terminal_first", "terminal_repeat"):
            take = name.removeprefix("terminal_")
            hero_rows = phases[f"hero_death_{take}"]
            result_rows = phases[f"settlement_{take}"]
        else:
            first_result = case["result_frame"]
            hero_rows = [row for row in phases[name] if row["frame"] < first_result]
            result_rows = [row for row in phases[name] if row["frame"] >= first_result]
        terminal_phases[name] = {
            "hero_animation": phase_summary(hero_rows),
            "result_screen": phase_summary(result_rows),
        }
    spell_windows = []
    for index, event in enumerate(run["events"]):
        if event["action"] != "spell" or event["card"] not in ("CS2_029", "GAME_005"):
            continue
        first_frame = event["frame"]
        next_frame = run["events"][index + 1]["frame"] if index + 1 < len(run["events"]) else len(frames) + 1
        spell_frames = frames[first_frame - 1:next_frame - 1]
        if spell_frames:
            spell_windows.append({
                "card": event["card"], "turn": event["turn"],
                "first_frame": first_frame, "last_frame": spell_frames[-1]["frame"],
                "slowest_frame": max(spell_frames, key=lambda row: row["frame_usec"]),
                "summary": phase_summary(spell_frames),
            })
    return {
        "begin": run["begin"],
        "end": run["end"],
        "total": phase_summary(frames),
        "after_loading": phase_summary([row for row in frames if row["phase"] != "loading"]),
        "phases": {phase: phase_summary(rows) for phase, rows in phases.items()},
        "slowest_frames": [
            {**row, "actions": events_by_frame[row["frame"]]}
            for row in sorted(frames, key=lambda row: -row["frame_usec"])[:15]
        ],
        "events": run["events"],
        "fx_captures": run["fx_captures"],
        "fx_cases": run["fx_cases"],
        "scenario_cases": run.get("scenario_cases", []),
        "fx_terminal_phases": terminal_phases,
        "fx_viewport_peaks": run["fx_viewports"],
        "fx_effect_samples": run["fx_effects"],
        "spell_action_windows": spell_windows,
        "event_counts": run["event_counts"] or run["end"].get("events", {}),
        "profile_stages": {
            phase: {
                stage: {"samples": count, "mean_ms": round(total / (1000 * count), 3), "max_ms": maximum / 1000}
                for stage, (count, total, maximum) in stages.items()
            }
            for phase, stages in run["profile_stages"].items()
        },
        "profile_spikes": list(run["profile_spikes"].values()),
    }


def read_surface_stats(path, layer_filter):
    dump = path.read_text(encoding="utf-8", errors="replace")
    layers = list(SURFACE_LAYER.finditer(dump))
    results = []
    for index, layer in enumerate(layers):
        name = layer[1].strip()
        if layer_filter not in name:
            continue
        end = layers[index + 1].start() if index + 1 < len(layers) else len(dump)
        match = PRESENT_HISTOGRAM.search(dump, layer.end(), end)
        if match is None:
            continue
        buckets = {int(ms): int(count) for ms, count in re.findall(r"(\d+)ms=(\d+)", match[1]) if int(count)}
        count = sum(buckets.values())
        if not count:
            continue
        mean = sum(ms * frames for ms, frames in buckets.items()) / count
        ordered = sorted(buckets)
        cumulative = list(accumulate(buckets[ms] for ms in ordered))
        results.append({
            "layer": name,
            "approximate_present_fps": round(1000 / mean, 2) if mean > 0 else None,
            "present_interval_buckets_ms": buckets,
            "present_interval_bucket_distribution_ms": {
                "samples": count,
                "mean": round(mean, 3),
                **{
                    f"p{percentile}": next(ms for ms, n in zip(ordered, cumulative) if n * 100 >= count * percentile)
                    for percentile in (50, 95, 99)
                },
                "max": ordered[-1],
            },
        })
    if not results:
        raise ValueError(f"no present2present histogram for layer containing {layer_filter!r}")
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("captures", nargs="*", type=Path, help="one logcat capture per match")
    parser.add_argument("--surface-stats", action="append", type=Path, default=[], help="SurfaceFlinger --timestats -dump text file")
    parser.add_argument("--layer", default="SurfaceView", help="substring identifying the game surface in TimeStats")
    args = parser.parse_args()
    if not args.captures and not args.surface_stats:
        parser.error("provide a logcat capture or --surface-stats")
    results = {}
    for path in args.captures:
        try:
            results[str(path)] = summarize(read_capture(path))
        except (ValueError, OSError) as error:
            parser.exit(1, f"{path}: {error}\n")
    for path in args.surface_stats:
        try:
            results[str(path)] = read_surface_stats(path, args.layer)
        except (ValueError, OSError) as error:
            parser.exit(1, f"{path}: {error}\n")
    print(json.dumps(results, ensure_ascii=False, indent=2, allow_nan=False))


if __name__ == "__main__":
    main()
