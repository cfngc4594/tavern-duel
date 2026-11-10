"""Decode Godot 4.7.1 remote profiler JSONL without conflating timing domains."""
import argparse
import json
from collections import defaultdict
from pathlib import Path

SOURCE = 'https://github.com/godotengine/godot/blob/4.7.1-stable/servers/debugger/servers_debugger.cpp'


def number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError('expected number')
    return value


def count(value):
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise ValueError('expected nonnegative integer count')
    return value


def decode_servers(payload):
    if not isinstance(payload, list) or len(payload) < 8:
        raise ValueError('short servers payload')
    fields = ('frame_number', 'frame_time', 'process_time', 'physics_time', 'physics_frame_time', 'script_time')
    result = dict(zip(fields, map(number, payload[:6])))
    i = 7
    servers = []
    for _ in range(count(payload[6])):
        if i + 2 > len(payload) or not isinstance(payload[i], str):
            raise ValueError('invalid server header')
        name, size = payload[i], count(payload[i + 1])
        i += 2
        if size % 2 or i + size > len(payload):
            raise ValueError('invalid server value count')
        for j in range(i, i + size, 2):
            if not isinstance(payload[j], str):
                raise ValueError('invalid server function name')
            servers.append({'server': name, 'name': payload[j], 'seconds': number(payload[j + 1])})
        i += size
    if i >= len(payload):
        raise ValueError('missing script count')
    size = count(payload[i])
    i += 1
    if size % 5 or i + size != len(payload):
        raise ValueError('invalid script value count or trailing values')
    functions = []
    for j in range(i, i + size, 5):
        functions.append(dict(zip(('signature_id', 'calls', 'self_seconds', 'total_seconds', 'internal_seconds'),
                                  [count(payload[j]), count(payload[j + 1]), *map(number, payload[j + 2:j + 5])])))
    result.update(servers=servers, functions=functions)
    return result


def decode_visual(payload):
    if not isinstance(payload, list) or len(payload) < 2:
        raise ValueError('short visual payload')
    size = count(payload[1])
    if size % 3 or len(payload) != size + 2:
        raise ValueError('invalid visual value count')
    areas = []
    for i in range(2, len(payload), 3):
        if not isinstance(payload[i], str):
            raise ValueError('invalid visual marker name')
        areas.append({'name': payload[i], 'cpu_msec': number(payload[i + 1]), 'gpu_msec': number(payload[i + 2])})
    return {'frame_number': count(payload[0]), 'areas': areas}


def stats(values):
    if not values:
        return {'count': 0}
    ordered = sorted(values)
    return {'count': len(values), 'mean': sum(values) / len(values), 'min': ordered[0],
            'max': ordered[-1], 'p50': ordered[(len(values)-1)//2],
            'p95': ordered[int((len(values)-1)*.95)]}


def visual_spans(areas):
    """Matched, nested, same-frame enclosing spans; never sum child regions."""
    stack, spans = [], []
    for area in areas:
        name = area['name']
        if name.startswith('>'):
            stack.append((name[1:].strip(), area))
        elif name.startswith('<'):
            if not stack or stack[-1][0] != name[1:].strip():
                stack.clear()
                continue
            label, start = stack.pop()
            values = {key: area[key] - start[key] for key in ('cpu_msec', 'gpu_msec')}
            if all(value >= 0 for value in values.values()):
                spans.append({'path': '/'.join([entry[0] for entry in stack] + [label]), **values})
    return spans


def analyze(path):
    signatures, groups, errors, totals = {}, {}, [], []
    warnings, runtime_errors = [], []
    phase = 'before_first_phase'
    def group():
        return groups.setdefault(phase, {'frames': [], 'visual': [], 'functions': defaultdict(lambda: defaultdict(float))})
    with open(path, encoding='utf-8-sig') as stream:
        for line_number, line in enumerate(stream, 1):
            try:
                record = json.loads(line)
                message = record['message']
                if not isinstance(message, list) or len(message) != 3 or not isinstance(message[0], str) or not isinstance(message[2], list):
                    raise ValueError('invalid message envelope')
                command, _, payload = message
                if command == 'error':
                    item = {'line': line_number, 'payload': payload}
                    (warnings if len(payload) > 9 and payload[9] is True else runtime_errors).append(item)
                elif command == 'benchmark:phase':
                    if len(payload) != 3:
                        raise ValueError('invalid phase marker')
                    phase = f'{payload[0]}:round={payload[1]}:ticks={payload[2]}'
                elif command == 'benchmark:done':
                    phase = 'after_benchmark_done'
                elif command == 'servers:function_signature':
                    if len(payload) != 2 or not isinstance(payload[0], str):
                        raise ValueError('invalid signature')
                    signatures[count(payload[1])] = payload[0]
                elif command in ('servers:profile_frame', 'servers:profile_total'):
                    frame = decode_servers(payload)
                    if command.endswith('total'):
                        totals.append(frame)
                        continue
                    g = group()
                    g['frames'].append(frame)
                    for function in frame['functions']:
                        entry = g['functions'][function['signature_id']]
                        for key in ('calls', 'self_seconds', 'total_seconds', 'internal_seconds'):
                            entry[key] += function[key]
                elif command == 'visual:profile_frame':
                    group()['visual'].append(decode_visual(payload))
            except (ValueError, KeyError, TypeError, IndexError) as exc:
                errors.append({'line': line_number, 'error': str(exc)})
    output = {}
    for label, g in groups.items():
        markers = defaultdict(lambda: {'cpu_msec': [], 'gpu_msec': []})
        spans = defaultdict(lambda: {'cpu_msec': [], 'gpu_msec': []})
        for frame in g['visual']:
            for span in visual_spans(frame['areas']):
                for key in ('cpu_msec', 'gpu_msec'):
                    spans[span['path']][key].append(span[key])
            for area in frame['areas']:
                for key in ('cpu_msec', 'gpu_msec'):
                    markers[area['name']][key].append(area[key])
        functions = [dict(signature_id=k, name=signatures.get(k, f'<unknown:{k}>'), **v) for k, v in g['functions'].items()]
        output[label] = {
            'script_frame_count': len(g['frames']), 'visual_frame_count': len(g['visual']),
            'frame_metrics_seconds': {key: stats([f[key] for f in g['frames']]) for key in ('frame_time', 'process_time', 'physics_time', 'physics_frame_time', 'script_time')},
            'functions_by_self_seconds': sorted(functions, key=lambda f: f['self_seconds'], reverse=True),
            'visual_marker_values': {name: {key: stats(v) for key, v in values.items()} for name, values in markers.items()},
            'matched_visual_spans_milliseconds': {name: {key: stats(v) for key, v in values.items()} for name, values in spans.items()},
        }
    return {'source': str(path), 'evidence': [SOURCE], 'phases': output,
            'accumulated_totals_not_added_to_frames': totals, 'malformed_records': errors,
            'runtime_warnings': warnings, 'runtime_errors': runtime_errors,
            'caveats': [
                'Phases use the most recently received phase marker, not exact engine-time alignment. Queuing and GPU latency make boundary attribution uncertain.',
                'Functions may be truncated to the configured per-frame limit; absent functions are not zero-cost.',
                'Self, total and internal times are separate overlapping metrics; do not add them together. Calls are accumulated only from per-frame messages.',
                'Native entries are script-invoked native call instrumentation, not full C++ sampling.',
                'Visual marker values are raw CPU/GPU millisecond markers, potentially nested timestamps; averages are not independently additive durations.',
                'Frame metrics are seconds. Visual metrics are milliseconds. No GPU duration is inferred when markers are missing.',
                'Capture should contain one profiler session: signature IDs can be reused after restarting profiling.',
            ]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    text = json.dumps(analyze(args.input), indent=2)
    if args.output:
        args.output.write_text(text + '\n', encoding='utf-8')
    else:
        print(text)


if __name__ == '__main__':
    main()
