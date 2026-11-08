"""Audit ACTUAL ten-pass GPU readbacks against the independent source oracle.

python compare_gpu_pass_captures.py CAPTURE_DIR --manifest capture_manifest.json \
    --out audit.json [--artifacts DIFF_DIRECTORY]

This never launches a renderer. A manifest is required to distinguish GPU evidence
from the earlier CPU fixture. PNGs are decoded as raw bytes, without color changes.
No threshold is silently treated as source-GPU identity.
"""
from pathlib import Path
import argparse
import hashlib
import json
import numpy as np
from PIL import Image
from verify_highlight_formulas import scalar_pass, quantize_r8

ORDER = ['dark', 'grey', 'blend1', 'light1', 'blend2', 'light2', 'blend3', 'blur', 'clip', 'silhouette']
FORMULAS = {
    'blend1': ('HighlightMultiSampleBlend', 'dark', 'grey', -1.25),
    'blend2': ('HighlightMultiSampleBlend', 'blend1', 'light1', -1.25),
    'blend3': ('HighlightMultiSampleBlend', 'blend2', 'light2', -1.0),
    'blur': ('HighlightMultiSample', 'blend3', None, -1.5),
    'silhouette': ('HighlightMaskBlend', 'blur', 'clip', float(np.float32(-.8))),
}
LEVELS = {'dark': .25, 'grey': .5, 'light1': .75, 'light2': .75, 'clip': 1.0}
FACTORS = {name: factor for name, factor in zip(ORDER, [.3, .3, .3, .5, .5, 1, 1, 1, .92, 1])}


def codes(values):
    return np.rint(np.asarray(values) * 255).astype(np.int16)


def summary(expected, actual):
    delta = codes(actual) - codes(expected)
    error = np.abs(delta)
    y, x = np.unravel_index(int(np.argmax(error)), error.shape)
    return {'max_byte_error': int(error.max()), 'mean_byte_error': float(error.mean()),
            'different_pixels': int(np.count_nonzero(error)),
            'pixels_over_one_byte': int(np.count_nonzero(error > 1)),
            'canonical_exact': not bool(error.any()),
            'within_one_byte_diagnostic': bool(np.all(error <= 1)),
            'worst_pixel_xy': [int(x), int(y)],
            'worst_actual_expected': [int(codes(actual)[y, x]), int(codes(expected)[y, x])]}


def audit(folder, manifest_path, artifact_dir=None, addressing_evidence=None):
    manifest = json.loads(manifest_path.read_text())
    problems = []
    warnings = []
    addressing = None
    if addressing_evidence:
        addressing = json.loads(addressing_evidence.read_text())
        if addressing.get('temporary_sampler', {}).get('u') != 'clamp' or addressing.get('temporary_sampler', {}).get('v') != 'clamp':
            warnings.append('Supplied evidence does not establish both temporary2D axes as clamp.')
    if manifest.get('capture_kind') != 'gpu_viewport_readback':
        problems.append('capture_kind must be gpu_viewport_readback; CPU or screenshot evidence is not accepted.')
    for field in ['renderer', 'case_id', 'capture_frame', 'base_size', 'passes']:
        if field not in manifest:
            problems.append('Missing manifest field: ' + field)
    rows = {row['name']: row for row in manifest.get('passes', [])}
    if len(rows) != 10 or set(rows) != set(ORDER):
        problems.append('Manifest must name exactly the ten source passes without duplicates.')
    if [r.get('name') for r in manifest.get('passes', [])] != ORDER:
        problems.append('Recorded pass order differs from the source schedule.')
    base = manifest.get('base_size', [0, 0])
    images = {}
    files = {}
    for number, name in enumerate(ORDER, 1):
        row = rows.get(name, {})
        f = folder / row.get('file', '%02d_%s.png' % (number, name))
        if not f.is_file():
            problems.append('Missing pass file: ' + str(f))
            continue
        with Image.open(f) as im:
            source_mode = im.mode
            array = np.asarray(im.convert('RGBA'))
            png_metadata = {key: str(value)[:200] for key, value in im.info.items()}
        red = array[:, :, 0]
        images[name] = red.astype(np.float64) / 255
        actual_size = [array.shape[1], array.shape[0]]
        # Source CIL evaluates dimension multiplication as float32, then truncates.
        expected_size = [max(1, int(np.float32(np.float32(n) * np.float32(FACTORS[name])))) for n in base]
        if actual_size != expected_size:
            problems.append('%s dimensions %s, expected source dimensions %s.' % (name, actual_size, expected_size))
        if row.get('size') != actual_size:
            problems.append(name + ' manifest size does not match PNG.')
        for key in ['frame', 'format', 'transparent_bg', 'use_hdr_2d', 'msaa_2d', 'filter', 'wrap']:
            if key not in row:
                problems.append(name + ' missing ' + key)
        if row.get('transparent_bg') is not True:
            problems.append(name + ': GLES3 nontransparent viewport is RGB10_A2, not R8-red equivalent.')
        if row.get('use_hdr_2d') is not False:
            problems.append(name + ': HDR must be disabled for 8-bit between-pass quantization.')
        if row.get('msaa_2d') not in [0, 'disabled', 'MSAA_DISABLED']:
            problems.append(name + ': MSAA is not the source single-sample replacement contract.')
        if str(row.get('format', '')).upper() not in ['RGBA8', 'FORMAT_RGBA8', 'GL_RGBA8', 'R8', 'FORMAT_R8', 'GL_R8']:
            problems.append(name + ': unexpected or missing target format.')
        if row.get('frame') != manifest.get('capture_frame'):
            problems.append(name + ': stage frame does not match completed generation frame.')
        if row.get('filter') not in ['linear', 'bilinear', 'filter_linear', 1]:
            problems.append(name + ': sampler is not bilinear.')
        if row.get('wrap') not in ['clamp', 'clamp_to_edge', 'repeat_disable']:
            warnings.append(name + ': current adapter contract is clamp, source native default remains unresolved.')
        files[name] = {'path': str(f), 'sha256': hashlib.sha256(f.read_bytes()).hexdigest(),
                       'size': actual_size, 'original_png_mode': source_mode,
                       'png_metadata_ignored_for_byte_comparison': png_metadata,
                       'rgb_channels_equal': bool(np.array_equal(array[:, :, 0], array[:, :, 1]) and np.array_equal(array[:, :, 0], array[:, :, 2])),
                       'alpha_codes': np.unique(array[:, :, 3]).tolist(),
                       'red_codes': np.unique(red).tolist(),
                       'nonzero_red_pixels': int(np.count_nonzero(red)),
                       'nonzero_red_border_pixels': int(np.count_nonzero(np.r_[red[0, :], red[-1, :], red[:, 0], red[:, -1]]))}
    replacements = []
    for name, value in LEVELS.items():
        if name not in images:
            continue
        canonical = int(codes(quantize_r8(value)))
        observed = np.unique(codes(images[name])).tolist()
        permitted = {n for n in range(256) if abs(n - value * 255) <= .6000001}
        row = {'pass': name, 'source_level': value, 'canonical_code': canonical,
               'observed_codes': observed, 'only_clear_and_source_level': set(observed).issubset({0, canonical}),
               'd3d_conversion_permitted_codes': sorted(permitted),
               'only_clear_and_permitted_source_level': set(observed).issubset({0} | permitted),
               'foreground_present': bool(np.any(images[name]))}
        replacements.append(row)
        if not row['only_clear_and_permitted_source_level']:
            problems.append(name + ': intermediate levels in constant mask, investigate target precision, MSAA, blending, color conversion, or readback.')
        elif not row['only_clear_and_source_level']:
            warnings.append(name + ': noncanonical rounding within D3D conversion tolerance; not evidence of a shader or color bug.')
        if not row['foreground_present']:
            warnings.append(name + ': mask is blank; numeric agreement on zero images is not useful actor evidence.')
    variants = []
    if len(images) == 10:
        for wrap in ['clamp', 'repeat']:
            for bits in [None, 8]:
                results = []
                for name, (kind, main, blend, offset) in FORMULAS.items():
                    row = rows[name]
                    main_size = [images[main].shape[1], images[main].shape[0]]
                    blend_size = [images[blend].shape[1], images[blend].shape[0]] if blend else None
                    if wrap == 'clamp' and bits is None:
                        for field, expected in [('main_size', main_size), ('blend_size', blend_size)]:
                            if row.get(field) != expected:
                                problems.append('%s %s mismatch: %s != %s' % (name, field, row.get(field), expected))
                        if not np.isclose(row.get('blur_offset', 999), offset, atol=1e-7, rtol=0):
                            problems.append(name + ': blur offset does not match source.')
                        ts = row.get('main_texel_size', [])
                        if len(ts) != 2 or not np.allclose(ts, 1 / np.array(main_size), atol=1e-9, rtol=1e-6):
                            problems.append(name + ': texel size is not reciprocal MAIN dimensions.')
                    expected = scalar_pass(kind, images[main], images[blend] if blend else None,
                                           images[name].shape, offset, wrap, bits)
                    result = {'pass': name, **summary(expected, images[name])}
                    results.append(result)
                    if artifact_dir and wrap == 'clamp' and bits is None:
                        artifact_dir.mkdir(parents=True, exist_ok=True)
                        Image.fromarray(codes(expected).astype(np.uint8), 'L').save(artifact_dir / (name + '_expected.png'))
                        delta = np.abs(codes(expected) - codes(images[name]))
                        Image.fromarray(np.minimum(delta * 32, 255).astype(np.uint8), 'L').save(artifact_dir / (name + '_absdiff_x32.png'))
                variants.append({'wrap': wrap, 'sample_fraction_bits': bits, 'passes': results,
                                 'selected_by_measured_addressing': bool(addressing and addressing.get('oracle_selected_wrap') == wrap),
                                 'all_canonical_exact': all(r['canonical_exact'] for r in results),
                                 'all_within_one_byte_diagnostic': all(r['within_one_byte_diagnostic'] for r in results)})
    return {'capture_manifest': str(manifest_path), 'capture_manifest_sha256': hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
            'capture_kind': manifest.get('capture_kind'), 'renderer': manifest.get('renderer'),
            'case_id': manifest.get('case_id'), 'metadata_contract_errors': problems,
            'metadata_contract_valid': not problems, 'warnings': warnings, 'files': files,
            'replacement_values': replacements, 'source_equation_variants': variants,
            'source_addressing_evidence': {'file': str(addressing_evidence), 'sha256': hashlib.sha256(addressing_evidence.read_bytes()).hexdigest(), 'data': addressing} if addressing_evidence else None,
            'actual_gpu_capture_claim': manifest.get('capture_kind') == 'gpu_viewport_readback',
            'scope': 'Readbacks supplied by QA; this script starts no GPU and cannot attest capture provenance independently. Five scalar outputs are compared against their ACTUAL input targets, with pixel centers (x+.5)/width and no Y flip or color conversion. One-byte results are diagnostic, not an automatic approval threshold. Original Unity GPU rasterization, live eligibility, source native wrap defaults, final highlight compositing and game behavior require separate evidence. CPU-precision exactness is deliberately not evaluated or labeled GPU proof.'}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('folder', type=Path)
    ap.add_argument('--manifest', required=True, type=Path)
    ap.add_argument('--out', required=True, type=Path)
    ap.add_argument('--artifacts', type=Path)
    ap.add_argument('--addressing-evidence', type=Path, help='Measured exact-API addressing provenance, kept with report.')
    args = ap.parse_args()
    report = audit(args.folder, args.manifest, args.artifacts, args.addressing_evidence)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ['case_id', 'metadata_contract_valid', 'metadata_contract_errors', 'warnings', 'source_equation_variants']}, indent=2))
    # Fail only evidence/contract errors. Numeric tolerance requires human review.
    raise SystemExit(0 if report['metadata_contract_valid'] else 2)


if __name__ == '__main__':
    main()
