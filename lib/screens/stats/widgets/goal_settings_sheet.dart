import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants.dart';
import '../../../components/glass_container.dart';
import '../../../providers/library_provider.dart';

class GoalSettingsSheet extends ConsumerStatefulWidget {
  const GoalSettingsSheet({super.key});

  @override
  ConsumerState<GoalSettingsSheet> createState() => _GoalSettingsSheetState();
}

class _GoalSettingsSheetState extends ConsumerState<GoalSettingsSheet> {
  late double _pagesValue;
  late double _minutesValue;
  late double _xpValue;
  late String _activeType;

  late TextEditingController _pagesController;
  late TextEditingController _minutesController;
  late TextEditingController _xpController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(libraryProvider);
    _pagesValue = state.weeklyPageGoal;
    _minutesValue = state.weeklyMinuteGoal;
    _xpValue = state.weeklyXPGoal;
    _activeType = state.weeklyGoalType;

    _pagesController = TextEditingController(
      text: _pagesValue.toInt().toString(),
    );
    _minutesController = TextEditingController(
      text: _minutesValue.toInt().toString(),
    );
    _xpController = TextEditingController(text: _xpValue.toInt().toString());
  }

  @override
  void dispose() {
    _pagesController.dispose();
    _minutesController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  void _updatePages(double newValue) {
    setState(() {
      _pagesValue = newValue.clamp(0, 10000);
      _pagesController.text = _pagesValue.toInt().toString();
    });
  }

  void _updateMinutes(double newValue) {
    setState(() {
      _minutesValue = newValue.clamp(0, 10000);
      _minutesController.text = _minutesValue.toInt().toString();
    });
  }

  void _updateXP(double newValue) {
    setState(() {
      _xpValue = newValue.clamp(0, 10000);
      _xpController.text = _xpValue.toInt().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GlassContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Reading Goals',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set targets for the metrics you want to track.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),

              _buildGoalInput(
                title: 'Pages Goal',
                unit: 'pages',
                controller: _pagesController,
                value: _pagesValue,
                isActive: _activeType == 'pages',
                onChanged: (val) => _pagesValue = val,
                onDecrement: () => _updatePages(_pagesValue - 10),
                onIncrement: () => _updatePages(_pagesValue + 10),
                onSelect: () => setState(() => _activeType = 'pages'),
              ),

              const SizedBox(height: 20),
              _buildGoalInput(
                title: 'Minutes Goal',
                unit: 'minutes',
                controller: _minutesController,
                value: _minutesValue,
                isActive: _activeType == 'minutes',
                onChanged: (val) => _minutesValue = val,
                onDecrement: () => _updateMinutes(_minutesValue - 10),
                onIncrement: () => _updateMinutes(_minutesValue + 10),
                onSelect: () => setState(() => _activeType = 'minutes'),
              ),

              const SizedBox(height: 20),
              _buildGoalInput(
                title: 'XP Goal',
                unit: 'XP',
                controller: _xpController,
                value: _xpValue,
                isActive: _activeType == 'xp',
                onChanged: (val) => _xpValue = val,
                onDecrement: () => _updateXP(_xpValue - 100),
                onIncrement: () => _updateXP(_xpValue + 100),
                onSelect: () => setState(() => _activeType = 'xp'),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ref
                        .read(libraryProvider.notifier)
                        .updateWeeklyGoals(
                          pages: _pagesValue,
                          minutes: _minutesValue,
                          xp: _xpValue,
                          activeType: _activeType,
                        );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: YomuConstants.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Goals'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalInput({
    required String title,
    required String unit,
    required TextEditingController controller,
    required double value,
    required bool isActive,
    required Function(double) onChanged,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required VoidCallback onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            GestureDetector(
              onTap: onSelect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? YomuConstants.accent.withOpacity(0.2)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isActive
                        ? YomuConstants.accent.withOpacity(0.5)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  isActive ? 'Active' : 'Show on Graph',
                  style: TextStyle(
                    color: isActive ? YomuConstants.accent : Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  IntrinsicWidth(
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isActive ? YomuConstants.accent : Colors.white,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        final dVal = double.tryParse(val);
                        if (dVal != null) {
                          onChanged(dVal);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 14,
                      color: YomuConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _buildValueBtn(Icons.remove, onDecrement),
                const SizedBox(width: 8),
                _buildValueBtn(Icons.add, onIncrement),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValueBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
