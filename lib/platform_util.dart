import 'dart:io' show Platform;

/// Whether we're running on an Android TV (or any Android device).
/// Used to gate GPU-heavy effects that choke low-end TV chipsets.
bool get isAndroidTV => Platform.isAndroid;

/// Best-effort tvOS detection.  The Dart runtime reports Platform.isIOS
/// for both iOS and tvOS, so we hard-code true here because this project
/// only ships to Apple TV (not iPhone/iPad).
bool get isTvOS => Platform.isIOS;

/// True on any TV form factor (Android TV or Apple TV).
bool get isTV => isAndroidTV || isTvOS;
