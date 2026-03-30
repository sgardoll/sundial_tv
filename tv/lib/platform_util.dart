import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Runtime TV-mode detection.
///
/// On Android we ask the platform for the UI-mode configuration flag.
/// A MethodChannel round-trip is async, so we resolve once at startup
/// and expose synchronous getters after that.
///
/// On iOS/tvOS the Dart runtime reports `Platform.isIOS` for both,
/// and this project only ships to Apple TV — so we hard-code true.

bool _resolvedIsAndroidTV = false;
bool _platformResolved = false;

/// Call once from main() before runApp().
Future<void> resolvePlatform() async {
  if (_platformResolved) return;
  _platformResolved = true;

  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel('com.connectio.sundial/platform');
      final result = await channel.invokeMethod<bool>('isTelevision');
      _resolvedIsAndroidTV = result ?? false;
    } catch (_) {
      // If the channel isn't available (e.g. test harness), assume not TV.
      _resolvedIsAndroidTV = false;
    }
  }
}

/// True only when running on an actual Android TV / Google TV device.
/// Returns false on phones, tablets, Chromebooks, etc.
bool get isAndroidTV => _resolvedIsAndroidTV;

/// Best-effort tvOS detection.  The Dart runtime reports Platform.isIOS
/// for both iOS and tvOS, so we hard-code true here because this project
/// only ships to Apple TV (not iPhone/iPad).
bool get isTvOS => Platform.isIOS;

/// True on any TV form factor (Android TV or Apple TV).
bool get isTV => isAndroidTV || isTvOS;

/// True on any Android device (TV, phone, tablet, Chromebook, etc.)
bool get isAndroid => Platform.isAndroid;
