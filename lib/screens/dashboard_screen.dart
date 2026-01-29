import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../components/glass_container.dart';
import '../components/book_card.dart';
import '../components/activity_graph.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: YomuConstants.horizontalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(context),
              const SizedBox(height: 30),
              _buildStreakCard(context),
              const SizedBox(height: 30),
              _buildContinueReading(context),
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
              const SizedBox(height: 100), // Bottom padding for navigation
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning,',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text('Reader', style: Theme.of(context).textTheme.displayLarge),
          ],
        ),
        const GlassContainer(
          width: 50,
          height: 50,
          borderRadius: 25,
          child: Icon(Icons.person_outline, size: 28),
        ),
      ],
    );
  }

  Widget _buildStreakCard(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      color: YomuConstants.accent,
      opacity: 0.15,
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Colors.orange,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '12 Day Streak!',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.orangeAccent),
                ),
                const Text('You\'re in the top 5% of readers this week.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueReading(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Continue Reading',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(onPressed: () {}, child: const Text('See All')),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              BookCard(
                title: 'Project Hail Mary',
                author: 'Andy Weir',
                coverUrl:
                    'https://m.media-amazon.com/images/I/81vdYEn9XPL._AC_UF1000,1000_QL80_.jpg',
                progress: 0.65,
              ),
              BookCard(
                title: 'The Midnight Library',
                author: 'Matt Haig',
                coverUrl:
                    'https://m.media-amazon.com/images/I/71K8iVRYLBL._AC_UF1000,1000_QL80_.jpg',
                progress: 0.32,
              ),
              BookCard(
                title: 'Hyperion',
                author: 'Dan Simmons',
                coverUrl: 'https://m.media-amazon.com/images/I/51pM1jA0QXL.jpg',
                progress: 0.12,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
