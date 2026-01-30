import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../components/glass_container.dart';
import 'dashboard_screen.dart';
import 'library_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

final selectedIndexProvider = StateProvider<int>((ref) => 0);

class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(selectedIndexProvider);

    final List<Widget> screens = [
      const DashboardScreen(), // Home
      const LibraryScreen(), // Library
      const StatsScreen(), // Stats
      const SettingsScreen(), // Settings
    ];

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: screens),
      extendBody: true,
      bottomNavigationBar: Padding(
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
              ),
              _buildNavItem(
                ref,
                index: 1,
                icon: Icons.menu_book_rounded,
                label: 'Library',
              ),
              _buildNavItem(
                ref,
                index: 2,
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
              ),
              _buildNavItem(
                ref,
                index: 3,
                icon: Icons.settings_rounded,
                label: 'Settings',
              ),
            ],
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
  }) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => ref.read(selectedIndexProvider.notifier).state = index,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
    );
  }
}
