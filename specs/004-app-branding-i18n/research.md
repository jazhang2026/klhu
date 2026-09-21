# Research: App Branding and Internationalization

**Feature**: 004-app-branding-i18n | **Date**: 2026-09-17

## Flutter Internationalization

### Decision: Use flutter_localizations and intl packages

**Rationale**: Flutter's official i18n solution provides robust localization support with ARB (Application Resource Bundle) files, automatic locale detection, and Material Design localization. Both packages are well-maintained and integrate seamlessly with Flutter's widget tree.

**Implementation Details**:
- `flutter_localizations`: Provides localized strings for Material/Cupertino widgets
- `intl`: Provides locale-specific formatting (dates, numbers) and message lookup
- ARB files (`app_en.arb`, `app_zh.arb`) store translations in JSON format
- `Localizations` widget provides `AppLocalizations` instance to descendant widgets

**Alternatives Considered**:
- Custom translation system: Rejected - would duplicate Flutter's built-in functionality
- Third-party i18n packages: Rejected - unnecessary complexity for 2-language support

## App Icon Configuration

### Decision: Platform-specific configuration with fallback

**Rationale**: App icons are platform-specific resources that cannot be configured dynamically from Flutter code. Both Android and iOS require specific icon files in specific directories/sizes.

**Android Implementation**:
- Place `kalahu.jpeg` in `android/app/src/main/res/mipmap-*/` directories with appropriate sizes
- Update `AndroidManifest.xml` `android:icon` attribute to reference the custom icon
- Generate multiple sizes (mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi) for different screen densities

**iOS Implementation**:
- Add icon to `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Update `Info.plist` CFBundleIconFile if needed
- iOS automatically handles icon scaling

**Fallback Strategy**:
- Check for icon file existence at runtime
- If missing, continue with default Flutter icon
- Log warning but don't crash

**Alternatives Considered**:
- Dynamic icon loading: Rejected - not supported by mobile platforms
- Cloud-based icon: Rejected - violates on-device-first principle

## App Title Localization

### Decision: Platform-specific string resources with Flutter integration

**Rationale**: App titles are displayed by the OS (home screen, app switcher) and require platform-specific configuration. UI titles within the app can use Flutter's i18n system.

**Android Implementation**:
- Add localized strings in `android/app/src/main/res/values/strings.xml` (English)
- Add `android/app/src/main/res/values-zh/strings.xml` (Chinese)
- Update `AndroidManifest.xml` `android:label` to reference `@string/app_name`
- Android automatically selects based on device locale

**iOS Implementation**:
- Add localized strings in `ios/Runner/Info.plist` using CFBundleDisplayName
- Create `ios/Runner/zh-Hans.lproj/InfoPlist.strings` for Chinese
- iOS automatically selects based on device locale

**Flutter UI Integration**:
- Use `AppLocalizations.of(context)!.appTitle` for in-app titles
- Ensure consistency between OS-level and in-app titles

**Alternatives Considered**:
- Single hardcoded title: Rejected - doesn't support localization
- Runtime title changes: Rejected - limited platform support

## Language Switching Implementation

### Decision: Shared preference persistence with MaterialApp locale configuration using dropdown

**Rationale**: Build on existing `shared_preferences` from spec 002, integrate with Flutter's `MaterialApp` locale support for consistent app-wide language switching. Use a dropdown interface that displays native language names and supports future expansion.

**Implementation Details**:
- Store language preference as `interface_language` key (values: "en", "zh-Hans")
- Create `LocalizationService` to manage preference loading/saving
- Update `MaterialApp` locale based on preference
- Integrate DropdownButton in reading view AppBar for language selection
- Display current language using native names ("English", "中文")
- Dropdown list shows available languages with native names
- Stop TTS reading before language change (integration with existing ReaderService)

**UI Integration**:
- Add language dropdown to reading view AppBar
- Use DropdownButton with native language names as display text
- Dropdown shows current language (device locale or selected preference)
- Tap dropdown to open list of available languages
- Update all descendant widgets when locale changes
- Handle rapid switching by using latest selection only

**Future Extensibility**:
- Design supports adding 2+ languages by extending the dropdown list
- Native language names ensure proper display for each language
- No architectural changes needed for additional languages

**Alternatives Considered**:
- System locale only: Rejected - doesn't allow user choice
- Per-screen language: Rejected - inconsistent user experience
- Separate language selector screen: Rejected - dropdown is more accessible and discoverable

## Integration with Existing Code

### Decision: Extend existing infrastructure without breaking changes

**Rationale**: Build on established patterns from specs 001-003 to maintain consistency and reduce complexity.

**Integration Points**:
- Extend `VoiceStore` pattern for language preference storage
- Integrate with existing `ReaderService` for TTS stopping on language change
- Follow existing widget test patterns for new components
- Maintain accessibility (VoiceOver/TalkBack) compliance

**Backward Compatibility**:
- Default to English if no preference set
- Preserve existing voice selection logic (spec 002)
- Maintain paragraph-based content language detection (spec 002)

## Performance Considerations

### Decision: Optimize for 1-second language switching requirement

**Implementation Strategy**:
- Load translations asynchronously during app initialization
- Cache AppLocalizations instance to avoid repeated lookups
- Use setState efficiently to minimize widget rebuilds
- Profile language switching performance on target devices

## Accessibility Considerations

### Decision: Maintain VoiceOver/TalkBack compliance

**Implementation Details**:
- Ensure language selector has proper semantic labels
- Announce language changes to screen readers
- Maintain minimum 44pt touch targets for language selector
- Test with both VoiceOver and TalkBack

## Testing Strategy

### Decision: Widget tests for language switching, integration tests for branding

**Test Coverage**:
- Widget tests for language selector UI and state changes
- Unit tests for localization service and preference persistence
- Integration tests for app icon and title verification on both platforms
- Manual accessibility testing with screen readers

## Dependencies

### Decision: Add flutter_localizations and intl packages

**Commands**:
```bash
flutter pub add flutter_localizations intl
flutter pub get
```

**Version**: Use latest stable versions compatible with Flutter 3.47.4

## Summary

All technical decisions align with Flutter best practices and klhu constitution requirements. The implementation leverages existing infrastructure while adding essential branding and i18n capabilities. No unresolved technical unknowns remain.