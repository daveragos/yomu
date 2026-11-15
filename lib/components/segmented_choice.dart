import 'package:flutter/material.dart';
import '../core/yomu_colors.dart';

/// One option of a [SegmentedChoice].
class SegmentedChoiceOption<T> {
  const SegmentedChoiceOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// A row of equal buttons where one is chosen, styled like the reader's
/// alignment buttons: the chosen one gets an accent outline and icon.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<SegmentedChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.yomu;
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Segment(
              option: options[i],
              isSelected: options[i].value == selected,
              colors: colors,
              onTap: () => onSelected(options[i].value),
            ),
          ),
        ],
      ],
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.isSelected,
    required this.colors,
    required this.onTap,
  });

  final SegmentedChoiceOption<T> option;
  final bool isSelected;
  final YomuColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? colors.accent : colors.textSecondary;
    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? colors.tint(0.1) : colors.tint(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? colors.accent : colors.tint(0.1),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(option.icon, size: 20, color: foreground),
                const SizedBox(height: 4),
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? colors.textPrimary : colors.textSecondary,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
