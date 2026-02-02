import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reader_settings_model.dart';
import '../providers/reader_settings_provider.dart';
import '../core/constants.dart';

class DisplaySettingsSheet extends ConsumerWidget {
  const DisplaySettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(readerSettingsProvider);
    final notifier = ref.read(readerSettingsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: YomuConstants.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Display Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Theme Section
            _buildSectionLabel('THEME'),
            const SizedBox(height: 12),
            _buildThemeSelector(settings, notifier),
            const SizedBox(height: 28),

            // Typeface Section
            _buildSectionLabel('TYPEFACE'),
            const SizedBox(height: 12),
            _buildTypefaceDropdown(settings, notifier),
            const SizedBox(height: 28),

            // Size & Layout Section
            _buildSectionLabel('SIZE & LAYOUT'),
            const SizedBox(height: 16),

            // Text Size Slider
            _buildSliderRow(
              label: 'Text Size',
              value: settings.textSize,
              min: 12,
              max: 32,
              displayValue: '${settings.textSize.round()}px',
              onChanged: (value) => notifier.setTextSize(value),
            ),
            const SizedBox(height: 16),

            // Line Height Slider
            _buildSliderRow(
              label: 'Line Height',
              value: settings.lineHeight,
              min: 1.0,
              max: 2.5,
              displayValue: settings.lineHeight.toStringAsFixed(1),
              onChanged: (value) => notifier.setLineHeight(value),
            ),
            const SizedBox(height: 20),

            // Alignment Buttons
            _buildAlignmentSelector(settings, notifier),
            const SizedBox(height: 28),

            // Publisher Defaults Toggle
            _buildPublisherDefaultsToggle(settings, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildThemeSelector(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: ReaderTheme.values.map((theme) {
        final isSelected = settings.theme == theme;
        final color = ReaderSettings.themePreviewColors[theme]!;

        return GestureDetector(
          onTap: () => notifier.setTheme(theme),
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? YomuConstants.accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypefaceDropdown(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: settings.typeface,
          isExpanded: true,
          dropdownColor: YomuConstants.surface,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          items: ReaderSettings.availableTypefaces.map((typeface) {
            return DropdownMenuItem(
              value: typeface,
              child: Text(
                typeface,
                style: TextStyle(
                  fontFamily: typeface == 'System' ? null : typeface,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              notifier.setTypeface(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            Text(
              displayValue,
              style: TextStyle(
                color: YomuConstants.accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: YomuConstants.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: YomuConstants.accent,
            overlayColor: YomuConstants.accent.withValues(alpha: 0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }

  Widget _buildAlignmentSelector(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Row(
      children: [
        _buildAlignmentButton(
          icon: Icons.format_align_left,
          isSelected: settings.alignment == ReaderAlignment.left,
          onTap: () => notifier.setAlignment(ReaderAlignment.left),
        ),
        const SizedBox(width: 8),
        _buildAlignmentButton(
          icon: Icons.format_align_center,
          isSelected: settings.alignment == ReaderAlignment.center,
          onTap: () => notifier.setAlignment(ReaderAlignment.center),
        ),
        const SizedBox(width: 8),
        _buildAlignmentButton(
          icon: Icons.format_align_justify,
          isSelected: settings.alignment == ReaderAlignment.justified,
          onTap: () => notifier.setAlignment(ReaderAlignment.justified),
        ),
      ],
    );
  }

  Widget _buildAlignmentButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? YomuConstants.accent.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? YomuConstants.accent
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? YomuConstants.accent : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildPublisherDefaultsToggle(
    ReaderSettings settings,
    ReaderSettingsNotifier notifier,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Publisher Defaults',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          Switch(
            value: settings.usePublisherDefaults,
            onChanged: (value) => notifier.togglePublisherDefaults(value),
            activeTrackColor: YomuConstants.accent.withValues(alpha: 0.5),
            activeThumbColor: YomuConstants.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}

/// Show the display settings as a bottom sheet
void showDisplaySettingsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const DisplaySettingsSheet(),
  );
}
