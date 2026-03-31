import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reader_settings_model.dart';
import './library_provider.dart';

const String _readerSettingsKey = 'reader_settings';

final readerSettingsProvider =
    StateNotifierProvider<ReaderSettingsNotifier, ReaderSettings>((ref) {
  return ReaderSettingsNotifier(ref);
});

class ReaderSettingsNotifier extends StateNotifier<ReaderSettings> {
  final Ref _ref;
  SharedPreferences? _prefs;
  Timer? _saveTimer;

  ReaderSettingsNotifier(this._ref) : super(ReaderSettings.defaults) {
    _loadSettings();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final settingsJson = _prefs?.getString(_readerSettingsKey);
      if (settingsJson != null) {
        final map = jsonDecode(settingsJson) as Map<String, dynamic>;
        state = ReaderSettings.fromMap(map);
      }
    } catch (e) {
      // Use defaults if loading fails
      state = ReaderSettings.defaults;
    }
  }

  void _saveSettings() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () async {
      try {
        _prefs ??= await SharedPreferences.getInstance();
        await _prefs?.setString(_readerSettingsKey, jsonEncode(state.toMap()));
      } catch (e) {
        // Silently fail - settings will be lost on restart
      }
    });
  }

  void setTheme(ReaderTheme theme) {
    final book = _ref.read(currentlyReadingProvider);
    final isPdf = book?.filePath.toLowerCase().endsWith('.pdf') ?? false;

    if (isPdf) {
      // For PDFs, we only update the transient active theme (temporary change)
      state = state.copyWith(
        theme: theme,
        usePublisherDefaults: false,
      );
    } else {
      // For EPUBs, we update both active theme AND sticky epubTheme preference
      state = state.copyWith(
        theme: theme,
        epubTheme: theme,
        usePublisherDefaults: false,
      );
    }
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

  void setLockState(ReaderLockState state) {
    this.state = this.state.copyWith(lockState: state);
    _saveSettings();
  }

  void toggleLockState() {
    final nextState = ReaderLockState
        .values[(state.lockState.index + 1) % ReaderLockState.values.length];
    setLockState(nextState);
  }

  void resetToDefaults() {
    state = ReaderSettings.defaults;
    _saveSettings();
  }
}
