import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/daily_word/daily_word_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/quiz/quiz_screen.dart';

class AppShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  @override
  set state(int value) => super.state = value;
}
final appShellTabProvider = NotifierProvider<AppShellTabNotifier, int>(AppShellTabNotifier.new);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  final List<Widget> _screens = const [
    DailyWordScreen(),
    QuizScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(appShellTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(appShellTabProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.quiz_outlined),
            selectedIcon: Icon(Icons.quiz_rounded),
            label: 'Quiz',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
