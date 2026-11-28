import 'dart:async';
import 'dart:io' show Platform;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../core/constants.dart';
import '../core/yomu_colors.dart';
import '../providers/library_provider.dart';
import '../models/book_model.dart';
import '../providers/shared_welcome_provider.dart';
import '../services/annotation_share_service.dart';
import '../services/incoming_files.dart';
import 'reading/widgets/shared_notes_prompts.dart';
import 'dashboard_screen.dart';
import 'library_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'reading_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../utils/tutorial_helper.dart';
import '../components/rank_up_dialog.dart';
import '../core/platform_caps.dart';
import '../core/breakpoints.dart';
import 'desktop/desktop_sidebar.dart';
import 'desktop/app_menu_bar.dart';
import '../components/desktop/route_shortcuts.dart';
import '../services/desktop_open_files.dart';
import '../services/celebrations.dart';

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

  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _libraryKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();

    // On a computer, books arrive from the file manager's Open With; on an
    // iPhone, from "Open in Yomu".
    if (PlatformCaps.hasOpenFilesChannel) {
      DesktopOpenFiles.listen((paths) {
        if (!mounted) return;
        _handleSharedFiles([
          for (final path in paths)
            SharedMediaFile(path: path, type: SharedMediaType.file),
        ]);
      });
    }

    if (!PlatformCaps.hasShareIntents) return;

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
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;

    final notifier = ref.read(libraryProvider.notifier);
    final summary = await notifier.importIncoming(
      files.map((f) => f.path).toList(),
    );

    var messages = summary.messages();
    var book = summary.bookToOpen;
    SharedImportResult? newNotes = summary.packages
        .where(
          (r) =>
              r.book != null &&
              r.book!.id == book?.id &&
              r.added + r.repliesAdded > 0,
        )
        .firstOrNull;

    // Notes made in another copy of a book that's in the library.
    if (book == null && mounted) {
      for (final r in summary.packages) {
        if (!r.isPending || r.similarBook == null || r.pendingPath == null) {
          continue;
        }
        final placed = await offerToPlaceNotes(
          context,
          pendingPath: r.pendingPath!,
          manifest: r.manifest,
          book: r.similarBook!,
        );
        if (placed != null) {
          book = placed.book;
          newNotes = placed;
          messages = [describeImport(placed)];
          await notifier.loadBooks();
          break;
        }
        if (!mounted) return;
      }
    }

    if (book != null && newNotes != null) {
      ref.read(sharedWelcomeProvider.notifier).state = SharedWelcome(
        bookId: book.id!,
        sharedBy: newNotes.manifest.sharedBy,
        newNotes: newNotes.added,
        newReplies: newNotes.repliesAdded,
      );
    }
    if (book != null) _openBook(book);

    if (mounted && messages.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(messages.join('\n')),
            duration: const Duration(seconds: 6),
          ),
        );
    }
  }

  void _openBook(Book book) {
    ref.read(currentlyReadingProvider.notifier).state = book;
    ref.read(libraryProvider.notifier).markBookAsOpened(book);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReadingScreen()),
      );
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
    // The sidebar sits on the left in wide windows, so the tips go beside it.
    final align = Breakpoints.isWide(context)
        ? ContentAlign.right
        : ContentAlign.top;
    final targets = [
      TutorialHelper.createTarget(
        identify: "home_target",
        keyTarget: _homeKey,
        title: "Home Dashboard",
        description:
            "Welcome to Yomu! Here you can quickly resume your current book and see your recent activity.",
        contentAlign: align,
      ),
      TutorialHelper.createTarget(
        identify: "library_target",
        keyTarget: _libraryKey,
        title: "Your Library",
        description:
            "Access all your imported books here. Tap the plus button to add new EPUB or PDF files.",
        contentAlign: align,
      ),
      TutorialHelper.createTarget(
        identify: "stats_target",
        keyTarget: _statsKey,
        title: "Reading Stats",
        description:
            "Track your reading habits, view your level, and check your achievements as you read more books.",
        contentAlign: align,
      ),
      TutorialHelper.createTarget(
        identify: "settings_target",
        keyTarget: _settingsKey,
        title: "App Settings",
        description:
            "Customize your reading experience, adjust your preferences, and access help or about sections.",
        contentAlign: align,
      ),
    ];

    TutorialHelper.showTutorial(
      context: context,
      targets: targets,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationStateProvider);
    final selectedIndex = navState.current;
    final isReverse = navState.current < navState.previous;

    // Global celebration listener (Rank Up)
    ref.listen(libraryProvider.select((s) => s.level), (previous, next) {
      final state = ref.read(libraryProvider);
      if (!state.isReading) {
        _checkAndShowRankUp(context, next, state);
      }
    });

    ref.listen(libraryProvider.select((s) => s.isReading), (previous, isReading) {
      if (previous == true && isReading == false) {
        final state = ref.read(libraryProvider);
        _checkAndShowRankUp(context, state.level, state);
      }
    });

    final List<Widget> screens = [
      const DashboardScreen(), // Home
      const LibraryScreen(), // Library
      const StatsScreen(), // Stats
      const SettingsScreen(), // Settings
    ];

    final isWide = Breakpoints.isWide(context);
    Widget screen = screens[selectedIndex];
    // In a wide window, screens stop growing at a width that suits them: the
    // dashboards lay out in columns, settings stays a single readable
    // column, and the library takes everything so its grid adds columns.
    final maxWidth = switch (selectedIndex) {
      1 => double.infinity,
      3 => Breakpoints.formMaxWidth,
      _ => Breakpoints.dashboardMaxWidth,
    };
    if (isWide && maxWidth.isFinite) {
      screen = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: screen,
        ),
      );
    }

    final content = PageTransitionSwitcher(
      // The sidebar and phone layouts place this in different parents; the
      // key carries the open screen's state across when the window resizes.
      key: _contentKey,
      duration: const Duration(milliseconds: 300),
      reverse: isReverse,
      transitionBuilder: (child, animation, secondaryAnimation) {
        // Sliding sideways mirrors swiping between tabs on a phone; with a
        // sidebar, a cross-fade reads better.
        if (isWide) {
          return FadeThroughTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            fillColor: Colors.transparent,
            child: child,
          );
        }
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
        child: screen,
      ),
    );

    if (isWide) {
      // ⌘1–⌘4 (Ctrl elsewhere) switch screens, as the sidebar hints show.
      final meta = Platform.isMacOS;
      return YomuMenuBar(
        destinations: _destinations,
        onShowScreen: _showScreenFromMenu,
        child: RouteShortcuts(
          bindings: {
            for (var i = 0; i < _destinations.length; i++)
              SingleActivator(
                LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
                meta: meta,
                control: !meta,
              ): () => _selectTab(i),
          },
          child: Scaffold(
            body: Row(
              children: [
                DesktopSidebar(
                  destinations: _destinations,
                  destinationKeys: _destinationKeys,
                  selectedIndex: selectedIndex,
                  onSelect: _selectTab,
                  onOpenBook: _openBook,
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      );
    }

    return YomuMenuBar(
      destinations: _destinations,
      onShowScreen: _showScreenFromMenu,
      child: Scaffold(
      body: content,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: context.yomu.surface,
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: context.yomu.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  _buildNavItem(
                    ref,
                    index: i,
                    icon: _destinations[i].icon,
                    label: _destinations[i].label,
                    itemKey: _destinationKeys[i],
                  ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  /// Menu bar screen commands also leave the reader if it's open.
  void _showScreenFromMenu(int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    _selectTab(index);
  }

  static const List<SidebarDestination> _destinations = [
    (icon: Icons.dashboard_rounded, label: 'Home'),
    (icon: Icons.menu_book_rounded, label: 'Library'),
    (icon: Icons.bar_chart_rounded, label: 'Stats'),
    (icon: Icons.settings_rounded, label: 'Settings'),
  ];

  /// The tutorial points at these, so the bottom bar and the sidebar attach
  /// the same keys to their items (only one of the two is ever built).
  late final _destinationKeys = [_homeKey, _libraryKey, _statsKey, _settingsKey];

  void _selectTab(int index) {
    final selectedIndex = ref.read(navigationStateProvider).current;
    if (selectedIndex != index) {
      ref.read(navigationStateProvider.notifier).state = NavigationState(
        current: index,
        previous: selectedIndex,
      );
    }
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
    final colors = context.yomu;

    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          key: itemKey,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? colors.accent
                  : colors.textSecondary,
              size: 28,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _checkAndShowRankUp(BuildContext context, int nextLevel, LibraryState state) {
    final currentRank = YomuConstants.getRankForLevel(
      nextLevel,
      state.unlockedAchievements.length,
    );
    final lastRank = YomuConstants.getRankForLevel(
      state.lastCelebratedLevel,
      state.unlockedAchievements.length,
    );

    if (currentRank.level > lastRank.level) {
      // Desktop shows a passing toast in the corner; phones keep the dialog.
      if (PlatformCaps.isDesktop) {
        Celebrations.show(
          Celebration(
            kind: CelebrationKind.rank,
            key: 'rank:${currentRank.name}',
            title: 'New rank',
            body: 'You are now ${currentRank.name}.',
          ),
        );
      } else {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              RankUpDialog(level: nextLevel, rankName: state.rankName),
        );
      }
      ref.read(libraryProvider.notifier).markLevelCelebrated(nextLevel);
    }
  }
}
