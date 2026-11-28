import 'dart:async';
import 'dart:io' show Directory, File, Platform, Process;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
// latest_all includes legacy zone IDs such as Asia/Calcutta, which Android
// still reports for some regions; latest.dart doesn't.
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

import '../core/platform_caps.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Whether the plugin initialized. When it didn't (an unsupported platform,
  /// or setup failed), every call below does nothing.
  bool _ready = false;

  Future<void> init() async {
    if (!PlatformCaps.hasLocalNotifications) return;

    tz.initializeTimeZones();
    await _setLocalTimeZone();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // No permission prompts here: this runs before the first frame, and the
    // window would stay blank until the prompt was answered. The app asks
    // once it is on screen (requestPermissionsAfterLaunch).
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open Yomu',
        defaultIcon: AssetsLinuxIcon('assets/app_icon.png'),
      ),
    );

    // This runs before runApp, so a failure here must not stop the app from
    // starting: reminders are optional.
    try {
      await _notifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
        },
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  /// Asks for permission to show reminders, once the app is on screen.
  ///
  /// Nothing is shown where the answer is already known. The exact-alarm
  /// permission is deliberately not requested: it opens a system settings
  /// page, and reminders fall back to inexact alarms without it.
  Future<void> requestPermissionsAfterLaunch() async {
    try {
      await requestPermissions();
    } catch (e) {
      debugPrint('Could not request notification permission: $e');
    }
  }

  /// The timezone package starts with tz.local set to UTC, which would put a
  /// 20:00 reminder at 20:00 UTC. Schedule in the device's timezone instead.
  Future<void> _setLocalTimeZone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (e) {
      debugPrint('Could not set local timezone, reminders will use UTC: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Exact alarms need the "Alarms & reminders" permission, which Android 14+
  /// denies by default. Without it, scheduling an exact alarm throws, so use
  /// an inexact alarm instead; Android may then deliver it a little late.
  Future<AndroidScheduleMode> _androidScheduleMode() async {
    final android = _android;
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;
    try {
      if (await android.canScheduleExactNotifications() ?? false) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (e) {
      debugPrint('Could not check exact alarm permission: $e');
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Whether notifications are turned off in system settings, so asking again
  /// won't show a prompt.
  Future<bool> isBlockedBySystem() async {
    if (!PlatformCaps.hasPermissionHandler) return false;
    return (await Permission.notification.status).isPermanentlyDenied;
  }

  Future<bool> requestPermissions() async {
    if (!_ready) return false;

    // Linux desktops have no notification permission to ask for.
    if (Platform.isLinux) return true;

    if (Platform.isMacOS) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    // Request notification permission
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<PermissionStatus> getNotificationStatus() async {
    return await Permission.notification.status;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return;
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'yomu_engagement',
        'Engagement Notifications',
        channelDescription: 'Notifications for goals, streaks, and ranks',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!_ready) return;
    if (Platform.isLinux) {
      final time =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      return _scheduleLinux(
        id,
        title,
        body,
        '*-*-* $time:00',
        () => _nextInstanceOfTime(hour, minute),
      );
    }
    await _notifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOfTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'yomu_reminders',
          'Daily Reminders',
          channelDescription: 'Reminders to keep up your reading streak',
          importance: Importance.low,
          priority: Priority.low,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _androidScheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleWeekendBoostNotifications() async {
    if (!_ready) return;
    if (Platform.isLinux) {
      await _scheduleLinux(
        1000,
        '2x XP Weekend!',
        "It's the weekend! Earn double XP for all reading activities and quests.",
        'Sat *-*-* 10:00:00',
        () => _nextInstanceOfDayAndTime(DateTime.saturday, 10, 0),
      );
      await _scheduleLinux(
        1001,
        "Don't miss out on 2x XP!",
        "Last day of the weekend boost! Get your reading in and level up faster.",
        'Sun *-*-* 10:00:00',
        () => _nextInstanceOfDayAndTime(DateTime.sunday, 10, 0),
      );
      return;
    }
    final scheduleMode = await _androidScheduleMode();

    // Saturday 10:00 AM
    await _notifications.zonedSchedule(
      id: 1000,
      title: '2x XP Weekend!',
      body:
          "It's the weekend! Earn double XP for all reading activities and quests.",
      scheduledDate: _nextInstanceOfDayAndTime(DateTime.saturday, 10, 0),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'yomu_boosts',
          'Boost Notifications',
          channelDescription:
              'Notifications for 2x XP weekends and special events',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    // Sunday 10:00 AM
    await _notifications.zonedSchedule(
      id: 1001,
      title: "Don't miss out on 2x XP!",
      body:
          "Last day of the weekend boost! Get your reading in and level up faster.",
      scheduledDate: _nextInstanceOfDayAndTime(DateTime.sunday, 10, 0),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'yomu_boosts',
          'Boost Notifications',
          channelDescription:
              'Notifications for 2x XP weekends and special events',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int day, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Repeating reminders on Linux, which the notifications plugin can't
  /// schedule. Each one is a systemd user timer that shows the notification
  /// with `notify-send`, so it arrives even when Yomu is closed, like the
  /// scheduled notifications on other platforms. Without systemd or
  /// notify-send, they're shown while Yomu is running instead.
  Future<void> _scheduleLinux(
    int id,
    String title,
    String body,
    String onCalendar,
    tz.TZDateTime Function() next,
  ) async {
    _openTimers.remove(id)?.cancel();
    if (await _installReminderTimer(id, title, body, onCalendar)) return;
    _scheduleWhileOpen(id, title, body, next);
  }

  static Directory get _systemdUserDir {
    final env = Platform.environment;
    final config = env['XDG_CONFIG_HOME']?.isNotEmpty == true
        ? env['XDG_CONFIG_HOME']!
        : '${env['HOME']}/.config';
    return Directory('$config/systemd/user');
  }

  static String _reminderUnit(int id) => 'yomu-reminder-$id';

  /// The full path of [command] on PATH (minimal systems may lack `which`).
  static String? _findOnPath(String command) {
    for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
      if (dir.isEmpty) continue;
      final file = File('$dir/$command');
      if (file.existsSync()) return file.path;
    }
    return null;
  }

  /// Quotes [text] as one argument of a systemd `ExecStart=` line.
  static String _systemdArg(String text) =>
      '"${text.replaceAll('\\', '\\\\').replaceAll('"', '\\"').replaceAll('%', '%%').replaceAll(r'$', r'$$')}"';

  Future<bool> _installReminderTimer(
    int id,
    String title,
    String body,
    String onCalendar,
  ) async {
    try {
      final notifySend = _findOnPath('notify-send');
      if (notifySend == null) return false;
      final dir = _systemdUserDir;
      await dir.create(recursive: true);
      final unit = _reminderUnit(id);
      // The units outlive the app: uninstalling it can't remove files in
      // the user's home. The condition keeps them quiet once it's gone.
      final app = Platform.resolvedExecutable.replaceAll('%', '%%');
      await File('${dir.path}/$unit.service').writeAsString('''
[Unit]
Description=Yomu reading reminder
ConditionPathExists=$app

[Service]
Type=oneshot
ExecStart=$notifySend --app-name=Yomu --icon=com.ragoose.yomu --hint=string:desktop-entry:com.ragoose.yomu ${_systemdArg(title)} ${_systemdArg(body)}
''');
      await File('${dir.path}/$unit.timer').writeAsString('''
[Unit]
Description=Yomu reading reminder

[Timer]
OnCalendar=$onCalendar

[Install]
WantedBy=timers.target
''');
      final reload = await Process.run('systemctl', [
        '--user',
        'daemon-reload',
      ]);
      if (reload.exitCode != 0) return false;
      // restart, not just start, so a changed reminder time takes effect.
      await Process.run('systemctl', ['--user', 'enable', '$unit.timer']);
      final start = await Process.run('systemctl', [
        '--user',
        'restart',
        '$unit.timer',
      ]);
      return start.exitCode == 0;
    } catch (e) {
      debugPrint('Could not set up reminder timer: $e');
      return false;
    }
  }

  Future<void> _removeReminderTimer(int id) async {
    final unit = _reminderUnit(id);
    final timer = File('${_systemdUserDir.path}/$unit.timer');
    if (!await timer.exists()) return;
    try {
      await Process.run('systemctl', [
        '--user',
        'disable',
        '--now',
        '$unit.timer',
      ]);
      await timer.delete();
      await File('${_systemdUserDir.path}/$unit.service').delete();
      await Process.run('systemctl', ['--user', 'daemon-reload']);
    } catch (e) {
      debugPrint('Could not remove reminder timer: $e');
    }
  }

  /// Fallback when no systemd timer can be set up: reminders shown while
  /// Yomu runs, checked against the clock once a minute rather than with one
  /// long timer, which would run late after the computer sleeps.
  final Map<int, Timer> _openTimers = {};

  void _scheduleWhileOpen(
    int id,
    String title,
    String body,
    tz.TZDateTime Function() next,
  ) {
    _openTimers.remove(id)?.cancel();
    var due = next();
    _openTimers[id] = Timer.periodic(const Duration(minutes: 1), (_) {
      if (tz.TZDateTime.now(tz.local).isBefore(due)) return;
      due = next();
      showNotification(id: id, title: title, body: body);
    });
  }

  Future<void> cancel({required int id}) async {
    if (!_ready) return;
    _openTimers.remove(id)?.cancel();
    if (Platform.isLinux) await _removeReminderTimer(id);
    await _notifications.cancel(id: id);
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    for (final timer in _openTimers.values) {
      timer.cancel();
    }
    _openTimers.clear();
    await _notifications.cancelAll();
  }
}
