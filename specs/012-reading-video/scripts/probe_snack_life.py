#!/usr/bin/env python3
"""When does SC-001's message reach the page, and for how long is it readable?

A one-off probe beside the walk: it renders from the shipped pre-set, then — from
the *instant* the app reports the file — dumps the page back to back and prints,
per dump, how late it started and whether the message was on the page. The point
of the measurement is the row's own race: the message is a SnackBar, and a dump
that starts too late only ever reports the page after it has gone.

    $ python3 specs/012-reading-video/scripts/probe_snack_life.py
"""
import importlib.util
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location(
    "walk", os.path.join(HERE, "klhu_walk_video.py"))
walk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(walk)

walk.step("probe: a render from the shipped pre-set")
walk.hard_restart()
rows = walk.dump()
if not walk.tap(rows, "Video", label="the video action"):
    sys.exit(1)
time.sleep(1.5)
rows = walk.dump()
if not walk.tap(rows, "16:9 landscape 1080p", label="the landscape format"):
    sys.exit(1)
time.sleep(0.5)
rows = walk.dump()
if not walk.tap(rows, "Start", label="Start"):
    sys.exit(1)

# Polled the way the walk itself polls, so the lag it measures is the walk's.
walk.clear_logcat()
started = time.time()
done_at = None
while time.time() - started < 300:
    if "klhu render done" in walk.logcat():
        done_at = time.time()
        break
    time.sleep(0.5)
if done_at is None:
    print("no done line")
    sys.exit(1)
print(f"   the app's own line was seen {done_at - started:.2f}s after Start")

first, last = None, None
for attempt in range(8):
    began = time.time() - done_at
    rows = walk.dump()
    ended = time.time() - done_at
    hits = [l for l in walk.labels(rows) if "Video made" in l]
    if hits and first is None:
        first = began
    if hits:
        last = ended
    print(f"   dump {attempt}: began +{began:.2f}s, ended +{ended:.2f}s, "
          f"{len(rows)} nodes, {'MESSAGE ' + repr(hits[0]) if hits else 'gone'}")
print(f"   the message was readable from +{first:.2f}s to at least +{last:.2f}s"
      if first else "   the message was never read")
