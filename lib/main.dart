import 'dart:io' as io;
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'core/breakpoints.dart';
import 'core/platform_caps.dart';
import 'core/theme.dart';
import 'components/desktop/celebration_toasts.dart';
import 'screens/main_navigation.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
    for (final font in ['merriweather', 'lexend', 'gelasio']) {
      final text = await rootBundle.loadString('assets/fonts/OFL-$font.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
  // just_audio has no Linux player of its own; voice notes and audiobooks
  // play through libmpv there. Other platforms keep their native players.
  JustAudioMediaKit.title = 'Yomu';
  try {
    JustAudioMediaKit.ensureInitialized(linux: true, windows: false);
  } catch (e) {
    // libmpv isn't installed: the app still runs, only audio won't play.
    debugPrint('Audio playback unavailable: $e');
  }
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

  if (io.Platform.isLinux) {
    // F11 toggles full screen and Ctrl+Q quits, as in other Linux apps (the
    // macOS menu bar has both). The window lives in
    // linux/runner/my_application.cc.
    const window = MethodChannel('yomu/window');
    HardwareKeyboard.instance.addHandler((event) {
      if (event is! KeyDownEvent) return false;
      if (event.logicalKey == LogicalKeyboardKey.f11) {
        window.invokeMethod<void>('toggleFullScreen');
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyQ &&
          HardwareKeyboard.instance.isControlPressed) {
        window.invokeMethod<void>('close');
        return true;
      }
      return false;
    });
  }

  runApp(const ProviderScope(child: YomuApp()));

  // Only once the first frame is up, so an open permission prompt never
  // leaves the window blank.
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => NotificationService().requestPermissionsAfterLaunch(),
  );
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
      supportedLocales: const [Locale('en', 'US')],
      builder: (context, child) =>
          CelebrationToastHost(child: _TitleBarInset(child: child!)),
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
        viewPadding: mq.viewPadding.copyWith(top: mq.viewPadding.top + inset),
      ),
      child: result,
    );
  }
}
