"""Synthetic parser/comparison tests. No GPU and no game asset claims."""
from pathlib import Path
import json
import tempfile
import copy
import numpy as np
from PIL import Image
from compare_gpu_pass_captures import audit, ORDER, FORMULAS, FACTORS, LEVELS
from verify_highlight_formulas import scalar_pass, quantize_r8

ROOT = Path(__file__).parent


def main():
    tests = []
    with tempfile.TemporaryDirectory(prefix='harness_test_', dir=ROOT) as tmp:
        folder = Path(tmp)
        base = [80, 64]
        arrays = {}
        rows = []
        for index, name in enumerate(ORDER, 1):
            width, height = [max(1, int(np.float32(np.float32(n) * np.float32(FACTORS[name])))) for n in base]
            if name in LEVELS:
                # Deliberately asymmetric numeric test pattern, not actor geometry.
                y, x = np.mgrid[:height, :width]
                array = np.where((x > width * .17) & (x < width * .71) & (y > height * .29) & (y < height * .83), quantize_r8(LEVELS[name]), 0.)
            else:
                kind, m, b, offset = FORMULAS[name]
                array = scalar_pass(kind, arrays[m], arrays[b] if b else None, (height, width), offset)
            arrays[name] = array
            file = f'{index:02}_{name}.png'
            Image.fromarray(np.rint(array * 255).astype(np.uint8), 'L').save(folder / file)
            row = {'name': name, 'file': file, 'size': [width, height], 'frame': 0, 'format': 'GL_RGBA8',
                   'transparent_bg': True, 'use_hdr_2d': False, 'msaa_2d': 0, 'filter': 'bilinear', 'wrap': 'clamp'}
            if name in FORMULAS:
                _, m, b, offset = FORMULAS[name]
                ms = [arrays[m].shape[1], arrays[m].shape[0]]
                bs = [arrays[b].shape[1], arrays[b].shape[0]] if b else None
                row.update(main_size=ms, blend_size=bs, main_texel_size=[1/n for n in ms], blur_offset=offset)
            rows.append(row)
        manifest = {'capture_kind': 'synthetic_harness_unit_test', 'renderer': {'engine': 'none', 'backend': 'none'},
                    'case_id': 'synthetic_rectangles_not_gpu', 'capture_frame': 0, 'base_size': base, 'passes': rows}
        path = folder / 'manifest.json'

        def run(m):
            path.write_text(json.dumps(m))
            return audit(folder, path)

        report = run(manifest)
        assert not report['actual_gpu_capture_claim']
        assert len(report['metadata_contract_errors']) == 1 and 'capture_kind' in report['metadata_contract_errors'][0]
        assert report['source_equation_variants'][0]['all_canonical_exact']
        tests.extend(['synthetic_input_not_accepted_as_gpu', 'all_five_scalar_outputs_compared', 'source_size_factors_respected'])
        bad = copy.deepcopy(manifest)
        bad['passes'][4]['main_texel_size'] = [1/80, 1/64]
        assert any('texel size' in e for e in run(bad)['metadata_contract_errors'])
        tests.append('wrong_input_size_uniform_detected')
        bad = copy.deepcopy(manifest)
        bad['passes'][0]['transparent_bg'] = False
        assert any('RGB10_A2' in e for e in run(bad)['metadata_contract_errors'])
        tests.append('opaque_10bit_viewport_detected')
        bad = copy.deepcopy(manifest)
        bad['passes'][8]['frame'] = -1
        assert any('stage frame' in e for e in run(bad)['metadata_contract_errors'])
        tests.append('stale_generation_metadata_detected')
        p = folder / rows[-1]['file']
        array = np.asarray(Image.open(p)).copy()
        array[7, 9] = 37
        Image.fromarray(array, 'L').save(p)
        report = run(manifest)
        assert report['source_equation_variants'][0]['passes'][-1]['pixels_over_one_byte'] > 0
        tests.append('numeric_error_detected_at_actual_pixel')
    result = {'scope': 'Synthetic unit tests only. No GPU execution or actual GPU capture.',
              'passed': True, 'tests': tests, 'test_count': len(tests)}
    (ROOT / 'gpu_harness_selftest.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
