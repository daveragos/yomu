import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants.dart';

class ActivityGraph extends StatelessWidget {
  final Map<String, int> dailyValues;
  final String selectedMonth; // e.g., "January 2026"
  final String weeklyGoalType;

  const ActivityGraph({
    super.key,
    required this.dailyValues,
    required this.selectedMonth,
    required this.weeklyGoalType,
  });

  @override
  Widget build(BuildContext context) {
    // Parse selected month and year
    final DateFormat formatter = DateFormat('MMMM yyyy');
    final DateTime targetDate = formatter.parse(selectedMonth);
    final int year = targetDate.year;
    final int month = targetDate.month;

    final DateTime firstDayOfMonth = DateTime(year, month, 1);
    final DateTime lastDayOfMonth = DateTime(year, month + 1, 0);
    final int daysInMonth = lastDayOfMonth.day;
    final int firstWeekday = firstDayOfMonth.weekday; // 1 = Mon, 7 = Sun

    // GitHub/Finance style: 7 columns (Mon-Sun)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d) {
            return Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: daysInMonth + (firstWeekday - 1),
          itemBuilder: (context, index) {
            final int dayIndex = index - (firstWeekday - 1);
            if (dayIndex < 0) return const SizedBox.shrink();

            final DateTime date = DateTime(year, month, dayIndex + 1);
            final String dateStr = date.toIso8601String().split('T')[0];
            final int value = dailyValues[dateStr] ?? 0;

            return _buildDayCell(context, date.day, value);
          },
        ),
      ],
    );
  }

  Widget _buildDayCell(BuildContext context, int day, int value) {
    int level = 0;
    if (weeklyGoalType == 'pages') {
      if (value > 50)
        level = 4;
      else if (value > 20)
        level = 3;
      else if (value > 10)
        level = 2;
      else if (value > 0)
        level = 1;
    } else {
      if (value > 60)
        level = 4;
      else if (value > 30)
        level = 3;
      else if (value > 15)
        level = 2;
      else if (value > 0)
        level = 1;
    }

    final Color bgColor = YomuConstants.graphColors[level];
    final bool hasActivity = value > 0;
    final String label = value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}k'
        : '$value';

    return Container(
      decoration: BoxDecoration(
        color: hasActivity
            ? bgColor.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasActivity ? bgColor : Colors.white.withValues(alpha: 0.05),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: hasActivity ? Colors.black : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (hasActivity)
            Text(
              '${label}${weeklyGoalType == 'pages' ? 'p' : 'm'}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
