import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
// latest_10y is a much smaller database than latest_all, so it loads
// quickly and doesn't stall the UI at start-up.
import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules real OS notifications for task and document reminders.
///
/// Every caller (repositories) already goes through this class, so the
/// rest of the app didn't need to change when this stopped being a stub.
///
/// Rules:
/// - A reminder only exists when [enabled] is true AND [at] is set.
/// - One-off reminders fire once at [at] (skipped if that time has passed).
/// - Daily reminders (`daily: true`) repeat every day at [at]'s time of day.
/// - Calling schedule* again for the same id replaces the old reminder;
///   passing enabled=false or at=null cancels it.
/// - Anything that goes wrong here is logged, never thrown, so a
///   notification problem can't break saving a task or document.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _channelId = 'folio_reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription =
      'Reminders for task and document deadlines';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  // Tasks and documents both use auto-increment ids starting at 1, so they
  // would collide in one notification-id space. Tasks take even ids,
  // documents take odd ones.
  static int _taskNid(int id) => id * 2;
  static int _docNid(int id) => id * 2 + 1;

  Future<void>? _initFuture;

  /// Safe to call any number of times; the work happens once.
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    if (_ready) return;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);

      tzdata.initializeTimeZones();
      final localName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(localName));

      _ready = true;
    } catch (e) {
      // e.g. unsupported platform (desktop) or timezone lookup failure.
      debugPrint('NotificationService.init failed: $e');
    }
  }

  Future<void> scheduleForTask({
    required int id,
    required String title,
    required DateTime? at,
    required bool enabled,
    bool daily = false,
  }) =>
      _schedule(
        nid: _taskNid(id),
        title: title,
        body: daily ? 'Daily task reminder' : 'Task reminder',
        at: at,
        enabled: enabled,
        daily: daily,
      );

  Future<void> scheduleForDocument({
    required int id,
    required String title,
    required DateTime? at,
    required bool enabled,
  }) =>
      _schedule(
        nid: _docNid(id),
        title: title,
        body: 'Document deadline',
        at: at,
        enabled: enabled,
        daily: false,
      );

  Future<void> cancelForTask(int id) => _cancel(_taskNid(id));

  Future<void> cancelForDocument(int id) => _cancel(_docNid(id));

  // ─── internals ────────────────────────────────────────────────────────────

  Future<void> _cancel(int nid) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: nid);
    } catch (e) {
      debugPrint('NotificationService cancel failed: $e');
    }
  }

  Future<void> _schedule({
    required int nid,
    required String title,
    required String body,
    required DateTime? at,
    required bool enabled,
    required bool daily,
  }) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: nid); // always replace any previous reminder
      if (!enabled || at == null) return;
      if (!await _ensurePermission()) return;

      final now = tz.TZDateTime.now(tz.local);
      late final tz.TZDateTime when;
      DateTimeComponents? match;

      if (daily) {
        when = tz.TZDateTime(
            tz.local, now.year, now.month, now.day, at.hour, at.minute);
        match = DateTimeComponents.time;
        final next = when.isAfter(now) ? when : when.add(const Duration(days: 1));
        await _zoned(nid, title, body, next, match);
        return;
      }

      when = tz.TZDateTime.from(at, tz.local);
      if (!when.isAfter(now)) return; // already in the past
      await _zoned(nid, title, body, when, null);
    } catch (e) {
      debugPrint('NotificationService schedule failed: $e');
    }
  }

  Future<void> _zoned(int nid, String title, String body,
      tz.TZDateTime when, DateTimeComponents? match) async {
    await _plugin.zonedSchedule(
      id: nid,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _scheduleMode(),
      matchDateTimeComponents: match,
    );
  }

  /// Exact timing needs the "Alarms & reminders" permission, which Android 14+
  /// doesn't grant by default. Without it we fall back to inexact delivery
  /// (can be a few minutes late, but never silently dropped).
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canExact = await android?.canScheduleExactNotifications() ?? false;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Asks for notification permission the first time a reminder is actually
  /// enabled (Android 13+ / iOS), rather than at app launch.
  Future<bool> _ensurePermission() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (await android?.areNotificationsEnabled() ?? false) return true;
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }
}
