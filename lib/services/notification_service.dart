import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
// latest_all includes legacy zone IDs such as Asia/Calcutta, which Android
// still reports for some regions; latest.dart doesn't.
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    await _setLocalTimeZone();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
      },
    );

    // Request the notification permission on Android 13+. The exact-alarm
    // permission is deliberately not requested: it opens a system settings
    // page, and reminders fall back to inexact alarms without it.
    await _android?.requestNotificationsPermission();
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

  Future<bool> requestPermissions() async {
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
    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'yomu_engagement',
        'Engagement Notifications',
        channelDescription: 'Notifications for goals, streaks, and ranks',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
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
      ),
      androidScheduleMode: await _androidScheduleMode(),
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleWeekendBoostNotifications() async {
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

  Future<void> cancel({required int id}) async {
    await _notifications.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}
