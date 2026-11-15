import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'core/breakpoints.dart';
import 'core/platform_caps.dart';
import 'core/theme.dart';
import 'screens/main_navigation.dart';
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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // This ensures that the system navigation bar doesn't have an opaque background
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  runApp(const ProviderScope(child: YomuApp()));
}

class YomuApp extends StatelessWidget {
  const YomuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yomu',
      debugShowCheckedModeBanner: false,
      theme: YomuTheme.darkTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'),
      ],
      builder: (context, child) => _TitleBarInset(child: child!),
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
