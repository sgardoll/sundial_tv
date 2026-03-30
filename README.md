# Sundial

https://github.com/user-attachments/assets/fd63e7bb-d165-4640-8aee-8e78bfc3eb64

A clock that works like a real sundial. It uses your location to calculate where the sun actually is in the sky, then casts shadows in the correct direction — just as a physical sundial would. When the sun is low on the horizon, shadows stretch long and warm; at midday they shorten and cool. At night, the entire palette drops into deep blues and the shadows shift to a soft celestial glow. Everything — shadow angle, shadow length, colour temperature, and background lighting — is driven by the real position of the sun at your coordinates.

## Projects

| Directory | Platform | Stack |
|---|---|---|
| [`web/`](web/) | Browser (desktop, mobile, cast to TV) | Next.js, React, TypeScript |
| [`tv/`](tv/) | Android TV, Android phones/tablets, Chromebooks | Flutter, Dart, Kotlin |
| [`tv/ios/`](tv/ios/) | Apple TV (tvOS) | Native Swift/SwiftUI |

## Features

- **Location-aware solar tracking** — requests your coordinates once, then computes the sun's real azimuth and altitude using the NOAA/Meeus algorithm. Shadows point in the astronomically correct direction for your location, date, and time. Falls back to a time-only arc if location is denied.
- **Sundial shadows, not drop shadows** — the shadow is cast opposite the sun, exactly like a gnomon on a sundial. 60-step penumbra layers (24 on lower-powered Android TV chipsets) give it soft, graduated edges that fan out with distance. Shadow length grows as the sun approaches the horizon and shrinks toward zenith — matching the behaviour of a real sundial.
- **Shadow colour temperature** — warm amber tones at sunrise and sunset shift to cool blue-grey at midday, driven by the sun's altitude. Night shadows glow with a soft moonlit palette.
- **Day/night colour blending** — four palettes (night, sunrise, day, sunset) blend smoothly through the day. The background gradient tracks the sun's position across the sky, so the brightest point in the gradient follows the sun.
- **Volumetric lighting** — a lit-edge highlight on the sun-facing side of the numeral and a core shadow on the opposite side give the number a three-dimensional, physical presence.
- **Minute orbiting dot** — tracks the current minute around the numeral
- **Time simulation slider** — scrub through 24h to preview how shadows and colours change

### Web-only
- **Cast to TV** — Presentation API with AirPlay fallback

### TV / Mobile-only
- **Android screensaver (Daydream)** — registers as a system `DreamService` on all Android devices
- **Apple TV (tvOS)** — native SwiftUI app with its own solar position and shadow rendering

## Getting Started

### Web
```bash
cd web
npm install
npm run dev
```

### TV / Mobile
```bash
cd tv
flutter pub get
flutter run -d <device-id>
```

See each subdirectory's README for platform-specific instructions.
