# Sundial TV

Astronomical clock for **Android TV**, **Apple TV**, and all **Android** devices — a Flutter port of the [Sundial web app](../web).

Real solar shadows using the NOAA/Meeus algorithm. Background, colours, and lighting shift throughout the day.

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
- **Android screensaver (Daydream)** — registers as a system `DreamService` on all Android devices (TV, phone, tablet, Chromebook)

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

## Android

The `AndroidManifest.xml` includes:
- `LEANBACK_LAUNCHER` intent filter — app appears on Android TV home screen
- `android.software.leanback` feature (optional) — eligible for Play Store TV tab without excluding phones/tablets
- `android.hardware.touchscreen required="false"` — standard for TV apps
- `DreamService` screensaver — works on all Android devices (API 17+)

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

### Screensaver (Daydream / DreamService)

Sundial registers as a system screensaver via Android's `DreamService` on **all Android devices** — phones, tablets, Chromebooks, and Android TV. When activated, it displays the clock in a clean ambient mode with no interactive controls.

#### Phones & tablets

Go to **Settings → Display → Screen saver** (or **Daydream** on older versions), select **Sundial**, and choose when to activate (while charging, while docked, or either).

#### Chromebooks

**Settings → Device → Display → Screen saver** → select **Sundial**.

#### Android TV / Google TV

**On older devices (pre-Android TV 12):** Go to **Settings → Display → Screensaver** and select **Sundial** from the list.

**On Google TV / Android TV 12+:** The system UI no longer exposes third-party screensaver selection. Use ADB instead:

```bash
# Connect to your TV
adb connect <tv-ip-address>

# Set Sundial as the default screensaver
adb shell settings put secure screensaver_components com.connectio.sundial/com.sundial.sundial_tv.SundialDreamService

# Set screensaver timeout (e.g. 5 minutes = 300000ms)
adb shell settings put system screen_off_timeout 300000

# Test the screensaver immediately
adb shell am start -n com.connectio.sundial/com.sundial.sundial_tv.SundialDreamService

# Verify current screensaver setting
adb shell settings get secure screensaver_components
```

To restore the default screensaver:
```bash
adb shell settings delete secure screensaver_components
```

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
