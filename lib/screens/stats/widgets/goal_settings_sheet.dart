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
  late double _value;
  late String _type;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final state = ref.read(libraryProvider);
    _value = state.weeklyGoalValue;
    _type = 'pages';
    _controller = TextEditingController(text: _value.toInt().toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateValue(double newValue) {
    setState(() {
      _value = newValue.clamp(1, 10000);
      _controller.text = _value.toInt().toString();
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
                'Weekly Page Goal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              const Text(
                'I want to read...',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        IntrinsicWidth(
                          child: TextField(
                            controller: _controller,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: YomuConstants.accent,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              final dVal = double.tryParse(val);
                              if (dVal != null) {
                                setState(() {
                                  _value = dVal;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _type,
                          style: TextStyle(
                            fontSize: 16,
                            color: YomuConstants.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildValueBtn(Icons.remove, () {
                        _updateValue((_value - 10).clamp(1, 10000));
                      }),
                      const SizedBox(width: 12),
                      _buildValueBtn(Icons.add, () {
                        _updateValue((_value + 10).clamp(1, 10000));
                      }),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    ref
                        .read(libraryProvider.notifier)
                        .setWeeklyGoal(_value, _type);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: YomuConstants.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Save Goal'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
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
