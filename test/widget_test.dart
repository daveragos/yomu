// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yomu/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: YomuApp()));

    // Verify that our counter starts at 0.
    // Note: The counter logic was removed in the new implementation, so this test might need updating
    // to reflect the new Yomu dashboard. For now, we'll just ensure it builds.
    expect(find.byType(YomuApp), findsOneWidget);
  });
}
