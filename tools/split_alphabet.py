"""Split recorded alphabets on silence; originals are never modified."""
import argparse
import json
import wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--write', action='store_true')
parser.add_argument('--threshold', type=float, default=-38)
parser.add_argument('--gap', type=float, default=0.25)
args = parser.parse_args()
for language, source, alphabet in [
    ('es', 'spanish abc.wav', 'abcdefghijklmnñopqrstuvwxyz'),
    ('en', 'english abc.wav', 'abcdefghijklmnopqrstuvwxyz'),
]:
    with wave.open(str(ROOT / 'sounds/animalese mine' / source)) as wav:
        rate, channels, width = wav.getframerate(), wav.getnchannels(), wav.getsampwidth()
        raw = wav.readframes(wav.getnframes())
    if width == 2:
        samples = np.frombuffer(raw, '<i2').astype(float) / 32768
    elif width == 3:
        b = np.frombuffer(raw, np.uint8).reshape(-1, 3).astype(np.int32)
        values = b[:, 0] | b[:, 1] << 8 | b[:, 2] << 16
        samples = ((values ^ 0x800000) - 0x800000) / 8388608
    else:
        raise ValueError(f'Unsupported PCM width: {width}')
    samples = samples.reshape(-1, channels).mean(axis=1)
    block = int(rate * .01)
    rms = np.array([np.sqrt(np.mean(samples[i:i+block] ** 2)) for i in range(0, len(samples), block)])
    active = np.flatnonzero(rms > 10 ** (args.threshold / 20))
    groups = np.split(active, np.flatnonzero(np.diff(active) * .01 >= args.gap) + 1)
    regions = [(max(0, int(g[0]*block-rate*.035)), min(len(samples), int((g[-1]+1)*block+rate*.055)))
               for g in groups if len(g) >= 4]
    print(source, 'duration', round(len(samples)/rate, 2), 'segments', len(regions), 'expected', len(alphabet))
    print([(i+1, round(a/rate, 2), round(b/rate, 2)) for i, (a,b) in enumerate(regions)])
    if not args.write:
        continue
    if len(regions) != len(alphabet):
        raise ValueError('Segment count differs from alphabet; inspect before naming files.')
    folder = ROOT / 'project/audio/animalese' / language
    folder.mkdir(parents=True, exist_ok=True)
    manifest = []
    for letter, (a,b) in zip(alphabet, regions):
        filename = 'enye.wav' if letter == 'ñ' else letter + '.wav'
        target = folder / filename
        if target.exists():
            raise FileExistsError(target)
        clip = samples[a:b].copy()
        fade = min(int(rate*.005), len(clip)//2)
        clip[:fade] *= np.linspace(0, 1, fade)
        clip[-fade:] *= np.linspace(1, 0, fade)
        with wave.open(str(target), 'wb') as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(rate)
            out.writeframes((np.clip(clip, -1, 1)*32767).astype('<i2').tobytes())
        manifest.append(dict(letter=letter, file=filename, start_seconds=round(a/rate, 4), end_seconds=round(b/rate, 4)))
    (folder / 'segments.json').write_text(json.dumps(dict(source=source, threshold_db=args.threshold, silence_seconds=args.gap, segments=manifest), ensure_ascii=False, indent=2), encoding='utf-8')
