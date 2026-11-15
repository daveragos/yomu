import 'package:flutter/material.dart';
import '../core/breakpoints.dart';
import '../components/desktop/page_header.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/yomu_colors.dart';
import '../providers/library_provider.dart';
import '../providers/appearance_provider.dart';
import '../components/glass_container.dart';
import '../components/segmented_choice.dart';
import '../services/notification_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);
    final appearance = ref.watch(appearanceProvider);
    final colors = context.yomu;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          if (Breakpoints.isWide(context))
            const SliverSafeArea(
              bottom: false,
              sliver: SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 28, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: DesktopPageHeader(
                    title: 'Settings',
                    subtitle:
                        'Appearance, reminders, your rank, and how to support Yomu',
                  ),
                ),
              ),
            )
          else
          SliverAppBar(
            backgroundColor: colors.background.withValues(alpha: 0.8),
            floating: true,
            title: Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colors.textPrimary,
              ),
            ),
            centerTitle: true,
            elevation: 0,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),
              _buildSectionHeader(colors, 'Appearance'),
              _buildAppearanceCard(colors, appearance, ref),
              const SizedBox(height: 24),
              _buildSectionHeader(colors, 'Engagement'),
              _buildEngagementCard(colors, state),
              const SizedBox(height: 24),
              _buildSectionHeader(colors, 'Notifications'),
              _buildNotificationToggles(context, colors, state, notifier),
              const SizedBox(height: 48),
              _buildSectionHeader(colors, 'More'),
              _buildMoreCard(context, colors),
              const SizedBox(height: 48),
              _buildAboutSection(colors),
              const SizedBox(height: 120),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(YomuColors colors, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildAppearanceCard(
    YomuColors colors,
    AppAppearance appearance,
    WidgetRef ref,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Theme',
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 2),
            Text(
              "System follows your device's light or dark setting.",
              style: TextStyle(color: colors.tint(0.5), fontSize: 12),
            ),
            const SizedBox(height: 14),
            SegmentedChoice<AppAppearance>(
              selected: appearance,
              onSelected: (value) =>
                  ref.read(appearanceProvider.notifier).set(value),
              options: [
                SegmentedChoiceOption(
                  value: AppAppearance.system,
                  label: AppAppearance.system.label,
                  icon: Icons.brightness_auto_rounded,
                ),
                SegmentedChoiceOption(
                  value: AppAppearance.light,
                  label: AppAppearance.light.label,
                  icon: Icons.light_mode_rounded,
                ),
                SegmentedChoiceOption(
                  value: AppAppearance.dark,
                  label: AppAppearance.dark.label,
                  icon: Icons.dark_mode_rounded,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementCard(YomuColors colors, LibraryState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.tint(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.stars_rounded,
                    color: colors.accent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level ${state.level}',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        state.rankName,
                        style: TextStyle(
                          color: colors.tint(0.6),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${state.totalXP}',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'TOTAL XP',
                      style: TextStyle(
                        color: colors.tint(0.38),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggles(
    BuildContext context,
    YomuColors colors,
    LibraryState state,
    LibraryNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassContainer(
        child: Column(
          children: [
            SwitchListTile(
              value: state.notificationsEnabled,
              onChanged: (val) =>
                  notifier.updateNotificationSettings(enabled: val),
              title: Text(
                'Daily Reminders',
                style: TextStyle(color: colors.textPrimary),
              ),
              subtitle: Text(
                'Keep your reading streak alive',
                style: TextStyle(color: colors.tint(0.5)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
            ),
            if (state.notificationsEnabled)
              ListTile(
                title: Text(
                  'Reminder Time',
                  style: TextStyle(color: colors.textPrimary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.reminderHour.toString().padLeft(2, '0')}:${state.reminderMinute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: colors.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.tint(0.24),
                    ),
                  ],
                ),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(
                      hour: state.reminderHour,
                      minute: state.reminderMinute,
                    ),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: colors.isDark
                              ? ColorScheme.dark(
                                  primary: colors.accent,
                                  onPrimary: colors.onAccent,
                                  surface: colors.surface,
                                  onSurface: colors.textPrimary,
                                )
                              : ColorScheme.light(
                                  primary: colors.accent,
                                  onPrimary: colors.onAccent,
                                  surface: colors.surface,
                                  onSurface: colors.textPrimary,
                                ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (time != null) {
                    notifier.updateNotificationSettings(
                      hour: time.hour,
                      minute: time.minute,
                    );
                  }
                },
              ),
            Divider(color: colors.tint(0.1), height: 1),
            ListTile(
              leading: Icon(Icons.notification_important_rounded, color: colors.accent),
              title: Text(
                'Test Notification',
                style: TextStyle(color: colors.textPrimary),
              ),
              subtitle: Text(
                'Receive a test alert to verify reminders work.',
                style: TextStyle(color: colors.tint(0.5), fontSize: 12),
              ),
              trailing: Icon(Icons.send_rounded, color: colors.accent, size: 20),
              onTap: () async {
                if (await NotificationService().isBlockedBySystem()) {
                  if (context.mounted) {
                    showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: '',
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (context, anim1, anim2) => const SizedBox(),
                      transitionBuilder: (context, anim1, anim2, child) {
                        return Transform.scale(
                          scale: anim1.value,
                          child: Opacity(
                            opacity: anim1.value,
                            child: AlertDialog(
                              backgroundColor: colors.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text(
                                'Notifications Blocked',
                                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
                              ),
                              content: Text(
                                'Reading reminders are currently blocked by your system settings. Please enable them to stay on track!',
                                style: TextStyle(color: colors.tint(0.70)),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Maybe Later', style: TextStyle(color: colors.tint(0.38))),
                                ),
                                TextButton(
                                  onPressed: () {
                                    openAppSettings();
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'Open Settings',
                                    style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return;
                }

                final granted = await NotificationService().requestPermissions();
                if (granted) {
                  await NotificationService().showNotification(
                    id: 888,
                    title: 'Test Notification',
                    body: "Reminders are working correctly! Happy reading.",
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification permissions are required for reminders.'),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreCard(BuildContext context, YomuColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GlassContainer(
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                Icons.volunteer_activism_rounded,
                color: colors.accent,
              ),
              title: Text(
                'Support the Developer AKA RaGoose',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Support the developer and the project',
                style: TextStyle(
                  color: colors.tint(0.5),
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                Icons.open_in_new_rounded,
                color: colors.tint(0.24),
                size: 20,
              ),
              onTap: () async {
                final uri = Uri.parse('https://gurshaplus.com/ragoose');
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Could not launch \$uri: \$e');
                }
              },
            ),
            Divider(color: colors.tint(0.1), height: 1),
            ListTile(
              leading: Icon(
                Icons.code_rounded,
                color: colors.accent,
              ),
              title: Text(
                'Contribute on GitHub',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Help build the future of Yomu',
                style: TextStyle(
                  color: colors.tint(0.5),
                  fontSize: 12,
                ),
              ),
              trailing: Icon(
                Icons.open_in_new_rounded,
                color: colors.tint(0.24),
                size: 20,
              ),
              onTap: () async {
                final uri = Uri.parse('https://github.com/daveragos/yomu');
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Could not launch \$uri: \$e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(YomuColors colors) {
    return Center(
      child: Column(
        children: [
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.hasData 
                  ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}' 
                  : '...';
              return Text(
                'Yomu $version',
                style: TextStyle(color: colors.tint(0.24), fontSize: 12),
              );
            },
          ),
        ],
      ),
    );
  }
}
