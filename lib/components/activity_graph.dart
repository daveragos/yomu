import 'package:flutter/material.dart';
import '../core/constants.dart';

class ActivityGraph extends StatelessWidget {
  final List<int> activityData; // List of levels (0-4) for each day

  const ActivityGraph({super.key, required this.activityData});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reading Activity', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(20, (columnIndex) {
              return Column(
                children: List.generate(7, (rowIndex) {
                  final index = columnIndex * 7 + rowIndex;
                  final level = index < activityData.length
                      ? activityData[index]
                      : 0;
                  return Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: YomuConstants.graphColors[level],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 4),
            ...YomuConstants.graphColors.map(
              (color) => Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text('More', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
