import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'platform_util.dart';
import 'sundial_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: const SundialScreen(),
    );
  }
}
