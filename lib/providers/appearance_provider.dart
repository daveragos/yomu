import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light or dark app, or whatever the device is set to.
enum AppAppearance {
  system,
  light,
  dark;

  ThemeMode get themeMode => switch (this) {
    AppAppearance.system => ThemeMode.system,
    AppAppearance.light => ThemeMode.light,
    AppAppearance.dark => ThemeMode.dark,
  };

  String get label => switch (this) {
    AppAppearance.system => 'System',
    AppAppearance.light => 'Light',
    AppAppearance.dark => 'Dark',
  };
}

const String _appearanceKey = 'app_appearance';

/// The appearance saved last time, read before the first frame so the app
/// doesn't open in the wrong colours for a moment. `main` overrides this.
final initialAppearanceProvider = Provider<AppAppearance>(
  (ref) => AppAppearance.system,
);

final appearanceProvider =
    StateNotifierProvider<AppearanceNotifier, AppAppearance>(
      (ref) => AppearanceNotifier(ref.read(initialAppearanceProvider)),
    );

class AppearanceNotifier extends StateNotifier<AppAppearance> {
  AppearanceNotifier(super.initial);

  /// The saved appearance, or [AppAppearance.system] when none was chosen.
  static Future<AppAppearance> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_appearanceKey);
      return AppAppearance.values.firstWhere(
        (a) => a.name == name,
        orElse: () => AppAppearance.system,
      );
    } catch (_) {
      return AppAppearance.system;
    }
  }

  Future<void> set(AppAppearance appearance) async {
    if (state == appearance) return;
    state = appearance;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_appearanceKey, appearance.name);
    } catch (_) {
      // Not saved; the choice still holds until the app closes.
    }
  }

  /// The reader's day/night button: the opposite of what is on screen now,
  /// as an explicit choice (it leaves "System").
  Future<void> toggle(Brightness current) => set(
    current == Brightness.dark ? AppAppearance.light : AppAppearance.dark,
  );
}
