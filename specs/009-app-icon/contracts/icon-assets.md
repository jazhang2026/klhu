# Contract: Launcher icon assets

**Feature**: [009-app-icon](../spec.md) | **Plan**: [plan.md](../plan.md) | **Date**: 2026-09-23

The feature exposes no API. Its interface is the **resource set the two
platforms resolve at runtime** plus the **configuration that generates it**.
This file is the contract both sides must satisfy: the generator writes exactly
these paths, and the manifest/catalogue must find them.

## 1. Inputs (the declaration side)

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.4

flutter_launcher_icons:
  image_path: "images/kalahoo.jpeg"
  android: true
  ios: true
  adaptive_icon_background: "#ffffff"
  adaptive_icon_foreground: "images/kalahoo.jpeg"
  remove_alpha_ios: true
  background_color_ios: "#ffffff"
```

- Registration command: `dart run flutter_launcher_icons` (manual, dev-time).
- `adaptive_icon_foreground_inset` is deliberately **not** set (tool default 16 %).
- No `min_sdk_android` (it does not gate generation in 0.14.4).

## 2. Android resource contract

Resolved through `android/app/src/main/AndroidManifest.xml`
(`android:icon="@mipmap/ic_launcher"`), for every density:

| Resource path | Pixels | Kind |
|---|---|---|
| `res/mipmap-mdpi/ic_launcher.png` | 48 | legacy bitmap |
| `res/mipmap-hdpi/ic_launcher.png` | 72 | legacy bitmap |
| `res/mipmap-xhdpi/ic_launcher.png` | 96 | legacy bitmap |
| `res/mipmap-xxhdpi/ic_launcher.png` | 144 | legacy bitmap |
| `res/mipmap-xxxhdpi/ic_launcher.png` | 192 | legacy bitmap |
| `res/drawable-mdpi/ic_launcher_foreground.png` | 108 | adaptive layer (108 dp @1x) |
| `res/drawable-hdpi/ic_launcher_foreground.png` | 162 | adaptive layer (108 dp @1.5x) |
| `res/drawable-xhdpi/ic_launcher_foreground.png` | 216 | adaptive layer (108 dp @2x) |
| `res/drawable-xxhdpi/ic_launcher_foreground.png` | 324 | adaptive layer (108 dp @3x) |
| `res/drawable-xxxhdpi/ic_launcher_foreground.png` | 432 | adaptive layer (108 dp @4x) |
| `res/mipmap-anydpi-v26/ic_launcher.xml` | — | adaptive descriptor |
| `res/values/colors.xml` | — | `ic_launcher_background` = `#ffffff` |

The adaptive descriptor:

```xml
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground>
      <inset android:drawable="@drawable/ic_launcher_foreground" android:inset="16%"/>
  </foreground>
</adaptive-icon>
```

Rules the platforms rely on:

- **C1** Every density has both a legacy bitmap and an adaptive layer — a device
  picks by qualifier, so a missing one is a crash-to-default, not a warning.
- **C2** The legacy bitmaps and the 108 dp foregrounds come from the same source,
  so the two Android paths (API < 26 legacy, API ≥ 26 adaptive) cannot disagree
  about the art.
- **C3** The adaptive foreground is inset 16 % by XML, which draws it at
  73.4 dp inside a 108 dp layer: inside the 72 dp safe disc, so no launcher mask
  clips the subject (measured fit: 92.2 % of the subject is already inside the
  centre 66 % of the source).
- **C4** `values/colors.xml` is created if absent and holds exactly the one
  background colour; an existing unrelated colour must survive a re-run.
- **C5** No `drawable-*/ic_launcher_background.png` exists (colour background —
  a PNG background would be the other, mutually exclusive branch).
- **C6** `minSdk 24` is below the adaptive-icon API level 26; the `-v26`
  qualifier, not the floor, decides which descriptor a device loads.
- **C7** Neither Gradle nor the Xcode project is part of this contract:
  `android/app/build.gradle.kts` gains no icon entry, and
  `ios/Runner.xcodeproj/project.pbxproj` must stay untouched — the icon name is
  already declared by `ASSETCATALOG_COMPILER_APPICON_NAME`. The generator does
  rewrite `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` (a
  boolean, not a name) on every run, so a regeneration ends with
  `git checkout -- ios/Runner.xcodeproj/project.pbxproj` (see `breakpoint.md`
  divergence 1).

## 3. iOS asset-catalogue contract

`ios/Runner/Assets.xcassets/AppIcon.appiconset/` — the classic multi-size set:

- 15 PNGs: `Icon-App-<size>@<scale>.png` for 20², 29², 40², 60², 76², 83.5²
  (iPhone/iPad @1x/@2x/@3x) plus `Icon-App-1024x1024@1x.png`.
- `Contents.json` lists every file with `size`, `idiom`, `filename`, `scale`.

Rules:

- **C8** Every `filename` in `Contents.json` exists, and its pixel dimensions
  equal `size × scale` (83.5 → 167 px; 1024 → 1024 px).
- **C9** The PNGs have **no alpha channel** (`remove_alpha_ios`): today's
  committed set is RGBA, which the App Store rejects.
- **C10** The 1024² icon is the App Store validation target and is a downscale of
  the same source as Android's set.

## 4. Packaged-artifact contract (what the device actually loads)

| Claim | How it is checked |
|---|---|
| The APK ships the committed Android icons | `unzip -p app-debug.apk res/mipmap-xxhdpi/ic_launcher.png \| sha256sum` equals `sha256sum android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` |
| The APK declares them as *the* application icon | `~/Android/Sdk/build-tools/36.0.0/aapt2 dump badging app-debug.apk \| grep application-icon` |
| The adaptive descriptor is packaged | `unzip -l app-debug.apk \| grep anydpi` (resource shrinking may rename to `res/…/ic_launcher.xml`; the `anydpi-v26` qualifier is preserved in the manifest table) |
| The app bundle would carry the iOS set | `ios/Runner.xcassets` is copied into the Xcode target — *not verifiable here* (no macOS); checked structurally by C8/C9 |

## 5. Failure modes this contract makes visible

| Mistake | Symptom | Caught by |
|---|---|---|
| Generator run with `ios: false` | iOS set stale, Android new | C8/C9/quickstart 6 |
| Only `image_path` set, no adaptive pair | no adaptive XML written | C1, test (D8) |
| Source replaced with a non-square image | stretched icons | C2/I1 in `data-model.md` |
| Alpha left on the iOS icons | App Store rejection much later | C9 |
| `Contents.json` edited by hand | catalogue points at a missing file | C8 |
| Icons regenerated for macOS/web/Windows | unrelated binary churn in the diff | `I11`, quickstart 7 |
