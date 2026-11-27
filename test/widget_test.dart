import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yomu/main.dart';
import 'package:yomu/screens/main_navigation.dart';

void main() {
  testWidgets('the app starts and shows its main screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: YomuApp()));

    expect(find.byType(MainNavigation), findsOneWidget);

    // The bundled Outfit fonts load asynchronously; let them finish and the
    // app relayout for them before it's taken down.
    await tester.runAsync(GoogleFonts.pendingFonts);
    await tester.pump();

    // Take the app down, then let the timers its start-up animations and
    // loading scheduled run out, so none is left pending when the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
