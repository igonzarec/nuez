"""Split the supplied PCM recording at silence, preserving each complete crunch.

Usage: python tools/split_snow_steps.py SOURCE.wav OUTPUT_DIRECTORY
Requires numpy. Does not normalize or modify the source.
"""
import argparse
import json
from pathlib import Path
import wave
import numpy as np

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
with wave.open(str(args.source), 'rb') as src:
    params = src.getparams()
    if params.sampwidth != 2 or params.comptype != 'NONE':
        raise SystemExit('Expected uncompressed 16-bit PCM WAV.')
    samples = np.frombuffer(src.readframes(params.nframes), dtype='<i2').reshape(-1, params.nchannels)
window = round(params.framerate * 0.01)
normalized = samples.astype(np.float64) / 32768.0
usable = len(samples) // window * window
rms = np.sqrt(np.mean(normalized[:usable].reshape(-1, window, params.nchannels) ** 2, axis=(1, 2)))
active = np.flatnonzero(rms > 10 ** (-45 / 20))
groups = [g for g in np.split(active, np.where(np.diff(active) > 15)[0] + 1) if len(g) > 5]
if len(groups) != 5:
    raise SystemExit(f'Expected 5 steps, found {len(groups)}. Review the source before splitting.')
args.output.mkdir(parents=True, exist_ok=True)
manifest = []
for index, group in enumerate(groups, 1):
    start = max(0, int(group[0] * window - params.framerate * 0.025))
    end = min(len(samples), int((group[-1] + 1) * window + params.framerate * 0.06))
    segment = samples[start:end].astype(np.float64)
    fade = min(round(params.framerate * 0.005), len(segment) // 2)
    segment[:fade] *= np.linspace(0, 1, fade)[:, None]
    segment[-fade:] *= np.linspace(1, 0, fade)[:, None]
    filename = f'snow_step_{index:02}.wav'
    with wave.open(str(args.output / filename), 'wb') as target:
        target.setparams(params)
        target.writeframes(np.rint(segment).astype('<i2').tobytes())
    manifest.append({'file': filename, 'source_start_s': round(start / params.framerate, 4),
                     'source_end_s': round(end / params.framerate, 4),
                     'duration_s': round(len(segment) / params.framerate, 4)})
(args.output / 'segments.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
print(json.dumps(manifest, indent=2))
