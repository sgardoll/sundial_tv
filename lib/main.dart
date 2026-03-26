import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sundial_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to landscape on TV
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Fullscreen / hide system UI
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
