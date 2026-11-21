import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gradual/core/firebase/firebase_providers.dart';
import 'package:gradual/core/models/user_model.dart';
import 'package:gradual/core/theme/app_theme.dart';
import 'package:gradual/core/theme/theme_mode_controller.dart';
import 'package:gradual/features/profile/profile_screen.dart';

void main() {
  group('parseThemeMode', () {
    test('maps stored names to modes', () {
      expect(parseThemeMode('light'), ThemeMode.light);
      expect(parseThemeMode('dark'), ThemeMode.dark);
      expect(parseThemeMode('system'), ThemeMode.system);
    });

    test('falls back to system for missing or unknown values', () {
      expect(parseThemeMode(null), ThemeMode.system);
      expect(parseThemeMode('sepia'), ThemeMode.system);
    });
  });

  group('loadSavedThemeMode', () {
    test('returns system when nothing is saved', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await loadSavedThemeMode(), ThemeMode.system);
    });

    test('returns the saved mode', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      expect(await loadSavedThemeMode(), ThemeMode.dark);
    });
  });

  group('ThemeModeController', () {
    test('starts from the initial mode override', () {
      final container = ProviderContainer(
        overrides: [initialThemeModeProvider.overrideWithValue(ThemeMode.light)],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });

    test('setMode updates state and persists the choice', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
      expect(await loadSavedThemeMode(), ThemeMode.dark);
    });
  });

  testWidgets('Profile appearance selector switches the theme mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final user = AppUser(
      uid: 'u1',
      email: 'test@example.com',
      fieldOfStudy: 'software_engineering',
      currentStreak: 0,
      lastActivityDate: null,
      activityLog: const {},
    );
    final container = ProviderContainer(
      overrides: [appUserProvider.overrideWith((ref) => Stream.value(user))],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ref.watch(themeModeProvider),
          home: const ProfileScreen(),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final darkSegment = find.text('Dark');
    await tester.scrollUntilVisible(darkSegment, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(darkSegment);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(themeModeProvider), ThemeMode.dark);
    final context = tester.element(find.byType(ProfileScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(context.colors.background, AppColors.dark.background);
    expect(tester.takeException(), isNull);
  });
}
