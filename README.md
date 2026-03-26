# Sundial TV

Astronomical clock for **Android TV** and **Apple TV** — a Flutter port of the [Sundial web app](../sundial).

Real solar shadows using the NOAA/Meeus algorithm. Background, colours, and lighting shift throughout the day.

## Project structure

```
lib/
  main.dart            — App entry point, orientation lock, immersive mode
  sundial_screen.dart  — Main UI: palette blending, gradient, layout, sliders
  sundial_painter.dart — CustomPainter: 60-step penumbra shadow + highlights
  solar_position.dart  — NOAA solar math (direct port from TypeScript)
```

## Running

```bash
flutter pub get

# Android TV emulator or device
flutter run -d <android-device-id>

# iPhone/iPad (iOS — for development)
flutter run -d <ios-device-id>
```

## Android TV

The `AndroidManifest.xml` already includes:
- `LEANBACK_LAUNCHER` intent filter — app appears on Android TV home screen
- `android.software.leanback` feature declaration — required for Google Play TV tab
- `android.hardware.touchscreen required="false"` — standard for TV apps

**Build APK:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Build Android App Bundle (for Play Store):**
```bash
flutter build appbundle --release
```

### D-pad navigation
- **Select / OK** → opens location entry dialog
- **Slider** — use arrow keys once slider is focused

## Apple TV (tvOS)

Flutter does not officially support tvOS. Use the community [`flutter_tvos`](https://github.com/nickaroot/flutter_tvos) plugin:

### Setup steps

1. **Add the plugin** to `pubspec.yaml`:
   ```yaml
   dependencies:
     flutter_tvos: ^0.0.4
   ```

2. **Run the tvOS setup script:**
   ```bash
   flutter pub get
   flutter pub run flutter_tvos:setup
   ```
   This generates a `tvos/` directory with an Xcode target.

3. **Open in Xcode:**
   ```bash
   open tvos/Runner.xcworkspace
   ```
   Set the deployment target to tvOS 15.0+, configure your signing team.

4. **Run on Apple TV simulator:**
   ```bash
   flutter run -d "Apple TV"
   ```

5. **Archive for App Store:**
   In Xcode → Product → Archive → Distribute App → App Store Connect

### tvOS UX notes
- The Siri Remote trackpad surface maps to swipe gestures
- The **Menu** button goes back / exits
- Focus engine handles navigation — no touchscreen
- Location must be entered manually via the dialog (no GPS on tvOS)

## Location

TV devices don't have GPS. The app shows a **"TAP TO SET LOCATION"** prompt in the top-right corner. Enter latitude and longitude manually — use Google Maps or your phone's location settings.

Without coordinates, the clock falls back to a time-based shadow arc (same behaviour as the web app when geolocation is denied).

## Features

- Real astronomical solar position (azimuth + altitude)
- 60-step penumbra shadow rendering via `CustomPainter`
- Altitude-driven shadow colour temperature (warm amber → cool blue-grey)
- Ambient occlusion contact shadow
- Volumetric highlight on the lit edge of the numeral
- Day/night palette blending (night → sunrise → day → sunset → night)
- Radial gradient background tracks celestial position
- Minute orbiting dot
- Time simulation slider (scrub through 24h)
- Immersive fullscreen, landscape-locked
- Manual location entry (TV-friendly)
