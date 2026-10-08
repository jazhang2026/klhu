#!/usr/bin/env python3
"""What a rendered video carries above 10 kHz, second by second.

The engine's voices hold nothing above 12 kHz — the on-device copy writes at
24 kHz, so its own Nyquist is 12 kHz, and its content stops before that. So any
level above 10 kHz in a render is the pipeline's, not the voice's, and a slice
where it is far louder than the file's own sentences is the hiss 012 FR-017
forbids: a sentence whose rate differed from the stream's, converted by linear
interpolation, which mirrors the voice's top octave above the source's Nyquist.

Measured this way (2026-10-06, AVD emulator-5554, 014's row 29 — a 24 kHz
narration and three 48 kHz roles in one render):

    linear interpolation   first 2 s  -21.1 dB   the file's own 48 kHz: -45..-50 dB
    windowed sinc          first 2 s  -49.0 dB   the file's own 48 kHz: -45..-54 dB

Usage:
    python3 klhu_probe_hiss.py <video.mp4> [<video.mp4> ...] [--max-first-db -35]

`--max-first-db` fails the run when any file's first two seconds sit above the
given ceiling. It is the ceiling the walk's expectation is written against, not
a property of any voice: -35 dB sits 14 dB above the fixed build's own reading
and 14 dB below the broken one's, so neither a quiet narration sentence nor a
noisy one can decide the outcome.

Needs ffmpeg on PATH (the walk's own dependency, not a new one: 012's rows
already pull files with ffprobe/ffmpeg for their stream checks).
"""
import os
import re
import subprocess
import sys
import wave

SECONDS = 6.0
WINDOW = 1.0
BAND = 10000


def sh(*args):
    return subprocess.run(args, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, text=True).stdout


def stream_of(path):
    out = sh('ffprobe', '-hide_banner', '-show_streams', '-select_streams', 'a', path)
    return dict(re.findall(r'^(\w+)=(\S+)$', out, re.M))


def wav_of(path, dest):
    sh('ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', path, '-vn',
       '-acodec', 'pcm_s16le', '-f', 'wav', dest)
    return dest


def per_second(wav):
    """The >10 kHz band's root-mean-square level, one number per [WINDOW]."""
    with wave.open(wav) as f:
        dur = f.getnframes() / f.getframerate()
    levels, t = [], 0.0
    while t < min(SECONDS, dur):
        out = sh('ffmpeg', '-hide_banner', '-nostats', '-ss', str(t),
                 '-t', str(WINDOW), '-i', wav,
                 '-af', 'highpass=f=%d,volumedetect' % BAND, '-f', 'null', '-')
        m = re.search(r'mean_volume: (-?[\d.]+)', out)
        levels.append((t, float(m.group(1)) if m else float('-inf')))
        t += WINDOW
    return levels


def mean_db(levels, lo, hi):
    vals = [v for (t, v) in levels if lo <= t < hi and v > -200]
    return sum(vals) / len(vals) if vals else float('-inf')


def main(argv):
    ceiling = None
    if '--max-first-db' in argv:
        i = argv.index('--max-first-db')
        ceiling = float(argv[i + 1])
        del argv[i:i + 2]
    if not argv:
        print(__doc__)
        return 2
    failed = False
    for path in argv:
        fields = stream_of(path)
        print('%s' % os.path.basename(path))
        print('  audio: %s %s Hz %sch %s bps, %s s' % (
            fields.get('codec_name'), fields.get('sample_rate'),
            fields.get('channels'), fields.get('bit_rate'),
            fields.get('duration')))
        wav = wav_of(path, '/tmp/klhu_hiss_%d.wav' % abs(hash(path)))
        levels = per_second(wav)
        first = mean_db(levels, 0.0, 2.0)
        print('  >%d kHz per second: %s' % (
            BAND // 1000, '  '.join('%4.1fs=%6.1f' % lv for lv in levels)))
        print('  first 2 s mean %6.1f dB  (a sentence that was converted lives here)' % first)
        if ceiling is not None and first > ceiling:
            print('  FAIL: above the ceiling of %.1f dB' % ceiling)
            failed = True
        os.unlink(wav)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
