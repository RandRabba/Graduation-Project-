import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'models.dart';

/// Schedules reminder notifications on the device.
abstract class ReminderScheduler {
  /// Asks for notification permission. Returns false if the user said no.
  Future<bool> requestPermission();

  /// Makes the device's schedule match [reminders] exactly: everything is
  /// cancelled first, then each enabled reminder is scheduled once.
  Future<void> sync(List<Reminder> reminders);

  Future<void> cancelAll();
}

/// Used in tests and on platforms without scheduled notifications.
class NoopReminderScheduler implements ReminderScheduler {
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> sync(List<Reminder> reminders) async {}
  @override
  Future<void> cancelAll() async {}
}

/// flutter_local_notifications on Android and iOS.
class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Your diabetes-care reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _init() => _ready ??= () async {
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // unknown zone name: tz.local stays UTC — one-off reminders still fire on time, repeats follow UTC
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // permission is asked when the patient first saves a reminder, not at launch
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<void> sync(List<Reminder> reminders) async {
    await _init();
    await _plugin.cancelAll();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    // exact alarms need a permission the user may not have granted; inexact can be a few minutes late
    final exact = await android?.canScheduleExactNotifications() ?? true;
    final now = DateTime.now();
    for (final r in reminders) {
      final next = r.enabled ? r.nextAfter(now) : null;
      if (next == null || r.id == null) continue;
      await _plugin.zonedSchedule(
        id: notificationId(r.id!),
        scheduledDate: tz.TZDateTime.from(next, tz.local),
        notificationDetails: _details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.description.isEmpty ? null : r.description,
        matchDateTimeComponents: switch (r.repeat) {
          ReminderRepeat.none => null,
          ReminderRepeat.daily => DateTimeComponents.time,
          ReminderRepeat.weekly => DateTimeComponents.dayOfWeekAndTime,
        },
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }
}

/// Stable 28-bit id from the reminder's hex id, so rescheduling replaces rather than duplicates.
int notificationId(String reminderId) {
  final hex = reminderId.replaceAll(RegExp('[^0-9a-fA-F]'), '');
  return int.tryParse(hex.padRight(7, '0').substring(0, 7), radix: 16) ??
      reminderId.hashCode & 0x0FFFFFFF;
}
