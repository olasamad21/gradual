import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'theme_mode';

/// Parses a stored theme mode name. Unknown or missing values mean system.
ThemeMode parseThemeMode(String? value) {
  for (final mode in ThemeMode.values) {
    if (mode.name == value) return mode;
  }
  return ThemeMode.system;
}

/// Reads the saved theme mode. Called in `main` before the first frame so the
/// app never flashes the wrong theme.
Future<ThemeMode> loadSavedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return parseThemeMode(prefs.getString(_themeModeKey));
  } catch (_) {
    return ThemeMode.system;
  }
}

/// Theme mode at startup. `main` overrides this with the saved value.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (_) {
      // Keep the in-memory choice even if saving fails.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
