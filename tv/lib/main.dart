import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'platform_util.dart';
import 'sundial_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve platform (TV vs phone/tablet) before building the UI.
  await resolvePlatform();

  // tvOS doesn't support orientation locking or immersive mode —
  // those calls silently hang the Flutter engine on Apple TV.
  if (!isTvOS) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(const SundialApp());
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
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final isScreensaver = settings.name == '/screensaver';
        return MaterialPageRoute(
          builder: (_) => SundialScreen(isScreensaver: isScreensaver),
        );
      },
    );
  }
}
