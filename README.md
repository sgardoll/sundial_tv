# Sundial

https://github.com/user-attachments/assets/fd63e7bb-d165-4640-8aee-8e78bfc3eb64

An astronomical clock with real solar shadows. The numeral, background, colours, and lighting shift throughout the day based on the actual position of the sun.

## Projects

| Directory | Platform | Stack |
|---|---|---|
| [`web/`](web/) | Browser (desktop, mobile, cast to TV) | Next.js, React, TypeScript |
| [`tv/`](tv/) | Android TV, Apple TV, Android phones/tablets, Chromebooks | Flutter, Dart, Kotlin |

## Features

- **Real astronomical solar position** — NOAA/Meeus algorithm computes azimuth and altitude for your coordinates
- **Geolocation-aware** — requests location once, falls back to time-only shadow arc if denied
- **60-step penumbra shadows** — soft, realistic shadow edges driven by real sun direction
- **Shadow colour temperature** — warm amber at sunrise/sunset, cool blue-grey at midday
- **Day/night palette blending** — smooth transitions through night → sunrise → day → sunset → night
- **Minute orbiting dot** — tracks the current minute around the numeral
- **Time simulation slider** — scrub through 24h to preview shadow changes

### Web-only
- **Cast to TV** — Presentation API with AirPlay fallback

### TV / Mobile-only
- **Android screensaver (Daydream)** — registers as a system `DreamService` on all Android devices
- **Apple TV (tvOS)** — native tvOS build via flutter_tvos

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
