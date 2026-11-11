# klhu — Agent Guide

KalaHoo Reading: a read-aloud Flutter app (EN / 简体中文 / Español).
Specs live in `specs/NNN-<feature>/` (spec.md, plan.md, tasks.md, research.md,
quickstart.md, breakpoint.md). Constitution and workflow rules are under
`.specify/`.

## Verification

- `flutter analyze --no-pub`
- `flutter test --concurrency=2` (lower concurrency when the emulator is running)
- Device walk: see the feature's `quickstart.md`

## Crash recovery — run this FIRST when the user reports a crash

**Symptom:** Devin Desktop (or the whole IDE) dies during `flutter test`,
`flutter run`, or `flutter build`, and every retry crashes again at the same
point — even for a trivial test file.

**Root cause (confirmed 2026-11-10):** `dart:frontend_server` balloons to
~13.6 GB RSS and the kernel OOM-killer terminates the whole IDE scope. The
trigger is a **corrupted incremental-compilation cache** left behind when an
earlier crash/OOM killed a compile mid-write — NOT the source code. The
poisoned file is `build/test_cache/*.cache.dill.track.dill` (tens of MB).
Because `flutter test` runs inside the IDE's process tree, the OOM victim is
the IDE itself.

**Fix — run immediately when a crash is reported:**

```bash
cd ~/Documents/GitHub/Projects/klhu
rm -rf build/test_cache .dart_tool/flutter_build
# or, heavier-handed: flutter clean
```

Then re-run the test. If `frontend_server` still exceeds ~8 GB, check
`journalctl --since "10 min ago" | grep oom-kill` for the victim process
before assuming it is the cache again.

**Prevention:** after any IDE crash during a Flutter build/test, clear the
cache BEFORE retrying — a killed compile leaves a corrupt dill that will OOM
every subsequent run. For extra safety on a memory-tight machine, run heavy
commands outside the IDE's cgroup:

```bash
systemd-run --user --scope -p MemoryMax=8G flutter test --concurrency=2
```

## Environment notes

- Android emulator AVD `klhu` uses ~4 GB RAM; Gradle/Kotlin daemons up to
  ~2 GB idle (`-Xmx8G` ceilings). Stop them (`./gradlew --stop`) when not
  building if memory is tight.
- Machine: 15 GiB RAM + ~4 GiB swap. Devin Desktop alone is ~2–3 GB.
