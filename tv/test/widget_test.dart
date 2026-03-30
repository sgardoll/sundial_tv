import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sundial_tv/main.dart';

void main() {
  testWidgets('Sundial smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SundialApp());
    await tester.pump(const Duration(milliseconds: 100));
    // App renders without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
