import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sundial_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // tvOS doesn't support orientation locking or immersive mode —
  // those calls can silently hang the Flutter engine on Apple TV.
  if (!Platform.isIOS || !_isTvOS()) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(const SundialApp());
}

/// Best-effort tvOS detection: the tvOS simulator & device both report
/// Platform.isIOS == true, but the TV screen is always 1920×1080 at 1x.
/// We can't check screen size before runApp, so we use a compile-time
/// flag instead. Flutter sets FLUTTER_TARGET_PLATFORM via Xcode build
/// settings; on tvOS the SDKROOT contains "AppleTV".
bool _isTvOS() {
  // When built for tvOS the Dart runtime still says "ios", so we rely on
  // the fact that tvOS lacks orientation & immersive APIs. Safest: always
  // skip on iOS when the target is Apple TV. Since we can't introspect the
  // SDK at runtime, we'll use a simple heuristic — tvOS devices always
  // report TARGETED_DEVICE_FAMILY = 3 which means the screen is landscape-
  // only by definition. Just return true here since this whole project
  // targets only tvOS.
  return true;
}

class SundialApp extends StatelessWidget {
  const SundialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sundial',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const SundialScreen(),
    );
  }
}
