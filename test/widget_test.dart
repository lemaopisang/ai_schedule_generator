import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_schedule_generator/main.dart';

void main() {
  testWidgets('App builds without error', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MainApp());

    // Verify that the app builds
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
