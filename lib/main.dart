import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'core/breakpoints.dart';
import 'core/platform_caps.dart';
import 'core/theme.dart';
import 'providers/appearance_provider.dart';
import 'components/desktop/celebration_toasts.dart';
import 'screens/main_navigation.dart';
import 'services/celebrations.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  if (PlatformCaps.isMobile) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  if (io.Platform.isAndroid) {
    // Bar icon colours follow the app's appearance (see YomuApp).
    // This ensures that the system navigation bar doesn't have an opaque background
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  final appearance = await AppearanceNotifier.load();
  runApp(
    ProviderScope(
      overrides: [initialAppearanceProvider.overrideWithValue(appearance)],
      child: const YomuApp(),
    ),
  );

  // Only once the first frame is up, so an open permission prompt never
  // leaves the window blank.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => NotificationService().requestPermissionsAfterLaunch(),
  );
}

class YomuApp extends ConsumerWidget {
  const YomuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp(
      title: 'Yomu',
      debugShowCheckedModeBanner: false,
      theme: YomuTheme.lightTheme,
      darkTheme: YomuTheme.darkTheme,
      themeMode: appearance.themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US')],
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        Celebrations.isDark = brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
        value: YomuTheme.systemBars(brightness),
        child: CelebrationToastHost(child: _TitleBarInset(child: child!)),
      );
      },
      home: const MainNavigation(),
    );
  }
}

/// Desktop framing for every screen: toasts styled for a wide window, and
/// the transparent macOS title bar reported as top padding, the way a phone
/// reports its status bar, so every screen's existing `SafeArea` keeps clear
/// of the traffic-light buttons without per-screen changes.
class _TitleBarInset extends StatelessWidget {
  final Widget child;

  const _TitleBarInset({required this.child});

  @override
  Widget build(BuildContext context) {
    // Wide windows get desktop toasts instead of the phone's bottom bar. The
    // Theme is always there so resizing across the breakpoint doesn't
    // rebuild every open screen.
    final theme = Theme.of(context);
    final Widget result = Theme(
      data: Breakpoints.isWide(context)
          ? theme.copyWith(snackBarTheme: YomuTheme.desktopSnackBarTheme(theme))
          : theme,
      child: child,
    );

    final inset = PlatformCaps.titleBarInset;
    if (inset == 0) return result;

    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(top: mq.padding.top + inset),
        viewPadding: mq.viewPadding.copyWith(
          top: mq.viewPadding.top + inset,
        ),
      ),
      child: result,
    );
  }
}
