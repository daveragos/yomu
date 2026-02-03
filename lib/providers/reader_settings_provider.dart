import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reader_settings_model.dart';

const String _readerSettingsKey = 'reader_settings';

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
      return ReaderSettingsNotifier();
    });

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  ReaderSettingsNotifier() : super(ReaderSettings.defaults) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_readerSettingsKey);
      if (settingsJson != null) {
        final map = jsonDecode(settingsJson) as Map<String, dynamic>;
        state = ReaderSettings.fromMap(map);
      }
    } catch (e) {
      // Use defaults if loading fails
      state = ReaderSettings.defaults;
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_readerSettingsKey, jsonEncode(state.toMap()));
    } catch (e) {
      // Silently fail - settings will be lost on restart
    }
  }

  void setTheme(ReaderTheme theme) {
    state = state.copyWith(theme: theme, usePublisherDefaults: false);
    _saveSettings();
  }

  void setTypeface(String typeface) {
    state = state.copyWith(typeface: typeface, usePublisherDefaults: false);
    _saveSettings();
  }

  void setTextSize(double size) {
    state = state.copyWith(
      textSize: size.clamp(12.0, 32.0),
      usePublisherDefaults: false,
    );
    _saveSettings();
  }

  void setLineHeight(double height) {
    state = state.copyWith(
      lineHeight: height.clamp(1.0, 2.5),
      usePublisherDefaults: false,
    );
    _saveSettings();
  }

  void setAlignment(ReaderAlignment alignment) {
    state = state.copyWith(alignment: alignment, usePublisherDefaults: false);
    _saveSettings();
  }

  void togglePublisherDefaults(bool value) {
    if (value) {
      // Reset to defaults when enabled
      state = ReaderSettings.defaults.copyWith(usePublisherDefaults: true);
    } else {
      state = state.copyWith(usePublisherDefaults: false);
    }
    _saveSettings();
  }

  void setAutoScrollSpeed(double speed) {
    state = state.copyWith(autoScrollSpeed: speed);
    _saveSettings();
  }

  void resetToDefaults() {
    state = ReaderSettings.defaults;
    _saveSettings();
  }
}
