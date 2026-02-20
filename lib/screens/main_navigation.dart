import 'dart:async';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../core/constants.dart';
import '../components/glass_container.dart';
import '../providers/library_provider.dart';
import 'dashboard_screen.dart';
import 'library_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'reading_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class NavigationState {
  final int current;
  final int previous;
  NavigationState({required this.current, required this.previous});
}

final navigationStateProvider = StateProvider<NavigationState>(
  (ref) => NavigationState(current: 0, previous: 0),
);

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  StreamSubscription? _intentDataStreamSubscription;

  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _libraryKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    // For sharing or opening while app is running
    _intentDataStreamSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          (List<SharedMediaFile> value) {
            if (mounted) {
              _handleSharedFiles(value);
            }
          },
          onError: (err) {
            debugPrint("getIntentDataStream error: $err");
          },
        );

    // For sharing or opening when app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (mounted) {
        _handleSharedFiles(value);
      }
    });

    _checkFirstLaunch();
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final paths = files.map((f) => f.path).toList();
    // Import files and get the list of imported/matching books
    final books = await ref.read(libraryProvider.notifier).importFiles(paths);

    // After import, try to open the first one
    if (books.isNotEmpty) {
      final book = books.first;
      ref.read(currentlyReadingProvider.notifier).state = book;
      ref.read(libraryProvider.notifier).markBookAsOpened(book);

      // Navigate to ReadingScreen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ReadingScreen()),
        );
      }
    }
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (isFirstLaunch && mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showTutorial();
        }
      });
    }
  }

  void _showTutorial() {
    final targets = [
      TargetFocus(
        identify: "home_target",
        keyTarget: _homeKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Home Dashboard",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Welcome to Yomu! Here you can quickly resume your current book and see your recent activity.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "library_target",
        keyTarget: _libraryKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Your Library",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Access all your imported books here. Tap the plus button to add new EPUB or PDF files.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "stats_target",
        keyTarget: _statsKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Reading Stats",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Track your reading habits, view your level, and check your achievements as you read more books.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "settings_target",
        keyTarget: _settingsKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "App Settings",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Customize your reading experience, adjust your preferences, and access help or about sections.",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: YomuConstants.accent,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onClickTarget: (target) {
        if (target.identify == "library_target") {
          ref.read(navigationStateProvider.notifier).state = NavigationState(
            current: 1,
            previous: 0,
          );
        } else if (target.identify == "stats_target") {
          ref.read(navigationStateProvider.notifier).state = NavigationState(
            current: 2,
            previous: 1, // Assuming moving forward
          );
        } else if (target.identify == "settings_target") {
          ref.read(navigationStateProvider.notifier).state = NavigationState(
            current: 3,
            previous: 2,
          );
        }
      },
      onFinish: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('is_first_launch', false);
        });
      },
      onSkip: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('is_first_launch', false);
        });
        return true;
      },
    )..show(context: context);
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationStateProvider);
    final selectedIndex = navState.current;
    final isReverse = navState.current < navState.previous;

    final List<Widget> screens = [
      const DashboardScreen(), // Home
      const LibraryScreen(), // Library
      const StatsScreen(), // Stats
      const SettingsScreen(), // Settings
    ];

    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 300),
        reverse: isReverse,
        transitionBuilder: (child, animation, secondaryAnimation) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            fillColor: Colors.transparent,
            child: child,
          );
        },
        child: Container(
          key: ValueKey<int>(selectedIndex),
          child: screens[selectedIndex],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: GlassContainer(
            height: 70,
            blur: 20,
            opacity: 0.1,
            borderRadius: 35,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  ref,
                  index: 0,
                  icon: Icons.dashboard_rounded,
                  label: 'Home',
                  itemKey: _homeKey,
                ),
                _buildNavItem(
                  ref,
                  index: 1,
                  icon: Icons.menu_book_rounded,
                  label: 'Library',
                  itemKey: _libraryKey,
                ),
                _buildNavItem(
                  ref,
                  index: 2,
                  icon: Icons.bar_chart_rounded,
                  label: 'Stats',
                  itemKey: _statsKey,
                ),
                _buildNavItem(
                  ref,
                  index: 3,
                  icon: Icons.settings_rounded,
                  label: 'Settings',
                  itemKey: _settingsKey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    WidgetRef ref, {
    required int index,
    required IconData icon,
    required String label,
    GlobalKey? itemKey,
  }) {
    final navState = ref.watch(navigationStateProvider);
    final selectedIndex = navState.current;
    final isSelected = selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (selectedIndex != index) {
            ref.read(navigationStateProvider.notifier).state = NavigationState(
              current: index,
              previous: selectedIndex,
            );
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          key: itemKey,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? YomuConstants.accent
                  : YomuConstants.textSecondary,
              size: 28,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: YomuConstants.accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
