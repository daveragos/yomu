import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../components/glass_container.dart';
import '../components/activity_graph.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(YomuConstants.horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickStats(context),
            const SizedBox(height: 30),
            const ActivityGraph(
              activityData: [
                1,
                2,
                0,
                4,
                3,
                2,
                1,
                0,
                1,
                3,
                2,
                2,
                4,
                1,
                0,
                4,
                3,
                1,
                2,
                4,
              ],
            ),
            const SizedBox(height: 30),
            _buildAchievements(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    return Row(
      children: [
        _buildStatItem(context, 'Books', '12', Icons.menu_book),
        const SizedBox(width: 16),
        _buildStatItem(context, 'Hours', '45.5', Icons.timer),
        const SizedBox(width: 16),
        _buildStatItem(context, 'Streak', '12d', Icons.local_fire_department),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: YomuConstants.accent, size: 24),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievements(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildBadge(context, 'Early Bird', Icons.wb_sunny, Colors.yellow),
            _buildBadge(context, 'Bookworm', Icons.bug_report, Colors.green),
            _buildBadge(context, 'Marathon', Icons.directions_run, Colors.blue),
            _buildBadge(context, 'Night Owl', Icons.dark_mode, Colors.indigo),
            _buildBadge(context, 'Scholar', Icons.school, Colors.purple),
            _buildBadge(context, 'Collector', Icons.inventory, Colors.orange),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(
    BuildContext context,
    String name,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        GlassContainer(
          width: 60,
          height: 60,
          borderRadius: 30,
          color: color,
          opacity: 0.2,
          child: Icon(icon, color: color, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
