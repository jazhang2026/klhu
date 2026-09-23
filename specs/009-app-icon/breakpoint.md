# Device validation: App Icon Update (009)

**Feature**: `009-app-icon` | **Date**: 2026-09-23
**Quickstart**: [quickstart.md](./quickstart.md) | **Spec**: [spec.md](./spec.md) | **Contract**: [contracts/icon-assets.md](./contracts/icon-assets.md)

## Environment

| | |
|---|---|
| Device | `emulator-5554` (AVD `klhu`, API 36, `sdk_gphone64_x86_64`, 1080×2400, Google/Nexus launcher) |
| Build | `flutter build apk --debug` → `adb install -r` → `pm clear com.example.klhu`, `lastUpdateTime` fresh |
| Source | working tree; `flutter analyze` clean, `flutter test --concurrency=2` → **234 passing, 0 failing** (218 before this feature + 16 in `test/app_icon_test.dart`) |
| Generator | `flutter_launcher_icons 0.14.4` (dev dependency), run by hand: `dart run flutter_launcher_icons` |
| Source art | `images/kalahoo.jpeg`, 1024×1024 RGB JPEG, uniform white background (edge mean 253–255) |
| Driver | `specs/009-app-icon/scripts/` (`ADB_SERIAL`, `KLHU_REPO`, `KLHU_OUT` env) + `adb`/`unzip`/`aapt2` by hand |

Rows are `WALKED` (device PASS plus the line that proves it), `[unit]`/`[structural]`
evidence, or `UNVERIFIED WITH REASON`. An icon is pixels, so a dump can never
carry the PASS on its own: the **packaged bytes** identify the resource, and a
**template match** against the OS's own rendering of that resource says whose art
it is.

## Validation results

| # | Scenario | State | Evidence |
|---|---|---|---|
| 1 | The launcher shows the custom icon | **WALKED — PASS** | `unzip -p app-debug.apk res/mipmap-mdpi-v4/ic_launcher.png \| sha256sum` = repo file `a9c1e58f…`, and `res/mipmap-xxhdpi-v4/ic_launcher.png` = `2dac8a32…` (byte-identical, so the launcher is loading our files); `aapt2 dump badging` names them for every density — `application-icon-{120,160,240,320,480,640}:'res/mipmap-anydpi-v26/ic_launcher.xml'`, `application: label='KalaHoo Reading'`; the app drawer's own node box for the app `(293,1370,540,1685)` yields the icon square `(293,1370,540,1617)`, which matches **our** art far better than the default icon still in `HEAD` — MAD 23.6 vs 108.4 (ratio **0.22**). Screenshots: `klhu_009_drawer.png`, `klhu_009_drawer_cell.png` |
| 2 | Every density is present at its declared size | **WALKED — [unit]** | `flutter test test/app_icon_test.dart` → 16/16 pass, including "mdpi is 48px" … "xxxhdpi is 192px" and the per-density adaptive layers |
| 3 | The adaptive icon is what Android 8+ draws | **WALKED — PASS** | The APK contains `res/mipmap-anydpi-v26/ic_launcher.xml` (556 B), `res/drawable-{m,h,xh,xxh,xxxh}dpi-v4/ic_launcher_foreground.png`, and **no** `ic_launcher_background.png` (colour background); `res/values/colors.xml` declares `ic_launcher_background = #ffffff`; on screen the icon is drawn masked (launcher shape) with the art whole — the app-info header's icon box `(410,580,670,840)` matches our art at MAD 46.2 vs 124.6 for the default (ratio **0.37**), with neighbours at 46.9/47.2 (a stable minimum, not a fluke). Screenshots: `klhu_009_settings.png`, `klhu_009_settings_cell.png` |
| 4 | A stale launcher cache does not keep the old icon | **WALKED — PASS** | `pm clear` + `install -r` then the app drawer/header checks above (the previous build's icon was the Flutter default): every check matches the new art, so no cache keeps the old bitmap. The generator is also idempotent — re-running it with an unchanged source/config produced byte-identical files (checked by hashing the whole generated set before/after) |
| 5 | A missing source cannot break the build (FR-006) | **WALKED — PASS** | With `images/kalahoo.jpeg` moved aside: `flutter build apk --debug` → **exit 0** (`✓ Built …app-debug.apk`), and `dart run flutter_launcher_icons` → **exit 2** with `PathNotFoundException: Cannot open file, path = 'images/kalahoo.jpeg'`; hashes of all 28 generated files unchanged by the failed run, source restored afterwards |
| 6 | The iOS asset set is generated and self-consistent | **STRUCTURAL — PASS (device half UNVERIFIED)** | 25 catalogue entries with filenames, 25 files checked, **0 violations**: every PNG's pixels equal `size × scale` (e.g. `20x20@2x` = 40, `83.5x83.5@2x` = 167, `1024x1024@1x` = 1024) and every file is **RGB with no alpha** (`remove_alpha_ios`); full size table in `scripts/ios_set_and_missing_source.py`'s output. No macOS/Xcode on this host ⇒ no simulator, no Xcode asset validation, no store-icon preview |
| 7 | Other platforms' icon sets are untouched | **STRUCTURAL — PASS** | `git diff --stat -- macos/ web/ windows/ linux/` → empty; the whole feature diff is `android/app/src/main/res/**`, `ios/Runner/Assets.xcassets/**`, `pubspec.yaml`, `pubspec.lock`, `test/app_icon_test.dart` (+ the spec artifacts). `android/app/build.gradle.kts`, `AndroidManifest.xml`, `values/strings.xml` and `ios/Runner.xcodeproj/project.pbxproj` are unchanged |

## Divergences (what the run showed that the plan/tasks did not anticipate)

1. **The generator rewrites the Xcode project, wrongly.** After a run,
   `ios/Runner.xcodeproj/project.pbxproj` had two edits:
   `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` flipped from
   `YES` to `AppIcon`. That key is a boolean (whether to emit Swift symbols for
   asset catalogs); the icon name is declared by
   `ASSETCATALOG_COMPILER_APPICON_NAME` (already `AppIcon` in this project). The
   change is gratuitous and semantically wrong, so it was **reverted**
   (`git checkout -- ios/Runner.xcodeproj/project.pbxproj`) and the revert is part
   of the regeneration runbook in `README.md`. `contracts/icon-assets.md` §2/C7
   now says the Xcode project is not part of this feature's contract either.
2. **The adaptive layers are 108 _dp_, not 108 px on every density.** The first
   draft of the contract and the data model said "108 each"; the generator's own
   table (`flutter_launcher_icons/lib/android.dart:21-27`) scales them —
   mdpi 108, hdpi 162, xhdpi 216, xxhdpi 324, xxxhdpi 432 — and that is what
   landed on disk. The safe-zone argument is unchanged (it is expressed in dp);
   the pixel assertions in the test are now per-density. Corrected in place in
   `contracts/icon-assets.md`, `data-model.md`, `tasks.md` (T002) and recorded in
   `research.md` § Grounding corrections 5.
3. **The generated iOS catalogue is 25 entries, not 15.** The generator's table
   carries the legacy iPhone/iPad sizes too (`50x50`, `57x57`, `72x72`, and the
   iPad `@1x` variants), so the test's "the shipped catalogue is 15 icons" count
   assertion was replaced by the required-size contract (the sizes a device and
   the App Store actually resolve) — a count snapshot would have been a
   change-detector, and it would have failed on a correct run.
4. **The launcher exports no icon nodes.** `uiautomator dump` on the workspace
   returns the wallpaper/search bar but no per-icon nodes, so an icon cell cannot
   be located the way spec 008's screens were. The workable path is the **app
   drawer**, where the app's node IS exported — its label box doubles as the icon
   cell (icon square at the top of the node) — and the **Settings app-info
   header**, whose label pins the icon column. Both were then compared by
   template match instead of eyeballed.
5. **The Settings app-info screen is a Compose/SPA surface with no `ImageView`.**
   The first attempt looked for a large `ImageView` node and found none; the icon
   box had to be searched for around the app-name label. Recorded because the
   obvious dump-based recipe silently returns nothing here.
6. **The iOS template's own icons were wrong before this feature.** The shipped
   default `Icon-App-20x20@2x.png` was 20×20 px (not 40), `@3x` also 20×20, and
   all of them RGBA. That is why the contract test went red on the first run for
   reasons unrelated to the new art — and it is a real defect the regeneration
   fixed.

## Kept limitations

- **The iOS half of SC-002 is unverified**: assets generated and structurally
  checked (scenario 6), device/store validation impossible without macOS.
- **The mask geometry is not measured.** The comparisons crop the central 60 % of
  the icon box precisely because the outer ring belongs to the launcher's mask
  and the app-info header's rounded corner; the claim is "the OS renders our art
  for that resource", not "the mask is a particular shape".
- **No pixel-exact screenshot diff of the launcher workspace**: its icons are not
  addressable (divergence 4), so the launcher row rests on the drawer cell +
  packaged bytes.
- The walk drove `emulator-5554` only; Android 7 (API 24) legacy-icon rendering
  was not exercised — every check ran on API 36, which uses the adaptive path.

## Re-running

```bash
cd /home/weihongzhang/Documents/GitHub/Projects/klhu
export PATH=$HOME/development/flutter/bin:$PATH
flutter analyze && flutter test --concurrency=2        # 234 tests, incl. test/app_icon_test.dart
flutter build apk --debug && adb -s emulator-5554 install -r \
  build/app/outputs/flutter-apk/app-debug.apk

export KLHU_REPO=$PWD KLHU_OUT=/tmp ADB_SERIAL=emulator-5554
python3 specs/009-app-icon/scripts/icon_render_check.py           # scenarios 1 + 3 (launcher/header template match)
python3 specs/009-app-icon/scripts/ios_set_and_missing_source.py  # scenarios 5 + 6 (needs `dart`, rebuilds the APK)

# regeneration itself (dev-only; revert the pbxproj afterwards — divergence 1)
dart run flutter_launcher_icons
git checkout -- ios/Runner.xcodeproj/project.pbxproj
```
