import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/daily_word/daily_word_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/quiz/quiz_screen.dart';
import '../../features/quiz/quiz_providers.dart';
import 'animated_quiz_icon.dart';

class AppShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  @override
  set state(int value) => super.state = value;
}
final appShellTabProvider = NotifierProvider<AppShellTabNotifier, int>(AppShellTabNotifier.new);

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final List<Widget> _screens = const [
    DailyWordScreen(),
    QuizScreen(),
    ProfileScreen(),
  ];

  bool _hasShownQuizBubble = false;
  bool _showQuizBubble = false;

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(appShellTabProvider);
    final quizState = ref.watch(quizButtonStateProvider(DateTime.now()));
    final isAvailable = quizState.isEnabled && !quizState.isCompleted;

    if (isAvailable && !_hasShownQuizBubble) {
      _hasShownQuizBubble = true;
      Future.microtask(() {
        if (!mounted) return;
        setState(() => _showQuizBubble = true);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _showQuizBubble = false);
        });
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
          if (_showQuizBubble && currentIndex != 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F2937),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      "This week's quiz is open",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            icon: AnimatedQuizIcon(),
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
