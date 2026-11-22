import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_plan.dart';

/// The device side of reminders. Tests swap in a fake.
abstract class ReminderPlatform {
  /// Whether this platform can show scheduled reminders at all.
  bool get isSupported;

  Future<void> init();

  /// Asks the OS for permission to post notifications. True when allowed.
  Future<bool> requestPermission();

  /// Whether reminders can fire at the exact minute. Without this, Android
  /// may deliver them up to an hour late.
  Future<bool> canScheduleExact();

  /// Opens the system page to allow exact alarms. Returns the new state.
  Future<bool> requestExact();

  Future<void> schedule(PlannedReminder reminder);

  Future<void> cancel(int id);

  /// Posts a reminder right now, to check it looks and arrives right.
  Future<void> showNow(ReminderMessage message);

  /// Phone maker, such as "Xiaomi". Empty when unknown.
  Future<String> manufacturer();

  /// Opens the maker's autostart page, or the app's settings. True if opened.
  Future<bool> openAutostartSettings();
}

/// Makers whose battery managers stop alarms for apps without autostart.
bool needsAutostart(String manufacturer) => const {
      'xiaomi',
      'redmi',
      'poco',
      'oppo',
      'realme',
      'vivo',
      'huawei',
      'honor',
      'oneplus',
      'tecno',
      'infinix',
      'itel',
    }.contains(manufacturer.trim().toLowerCase());

/// Android reminders through flutter_local_notifications.
class LocalNotificationsReminderPlatform implements ReminderPlatform {
  LocalNotificationsReminderPlatform([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  static const _device = MethodChannel('gradual/device');
  static const _channelId = 'daily_reminder';
  static const _channelName = 'Daily reminder';
  static const _channelDescription = "A daily nudge with the day's first word.";

  /// Matches the launcher icon gradient's middle green.
  static const _accent = Color(0xFF2E7D32);

  @override
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init() => _ready ??= _init();

  Future<void> _init() async {
    if (!isSupported) return;
    tzdata.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone name: keep UTC. Scheduling uses absolute instants, so
      // reminders still fire at the right moment.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_gradual'),
      ),
    );
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();
    final granted = await _android?.requestNotificationsPermission();
    if (granted != null) return granted;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> canScheduleExact() async {
    if (!isSupported) return false;
    await init();
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<bool> requestExact() async {
    if (!isSupported) return false;
    await init();
    await _android?.requestExactAlarmsPermission();
    return canScheduleExact();
  }

  NotificationDetails _details(ReminderMessage message) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          icon: 'ic_stat_gradual',
          color: _accent,
          largeIcon: const DrawableResourceAndroidBitmap('ic_reminder_large'),
          styleInformation: BigTextStyleInformation(
            message.expandedBody,
            contentTitle: message.title,
            summaryText: "Today's words",
          ),
          ticker: message.title,
        ),
      );

  @override
  Future<void> schedule(PlannedReminder reminder) async {
    if (!isSupported) return;
    await init();
    final exact = await canScheduleExact();
    await _plugin.zonedSchedule(
      id: reminder.id,
      scheduledDate: tz.TZDateTime.from(reminder.when, tz.local),
      notificationDetails: _details(reminder.message),
      // Exact when the user allows it; otherwise Android may batch the alarm
      // and deliver it up to an hour late.
      androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
      title: reminder.message.title,
      body: reminder.message.body,
      payload: 'today',
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (!isSupported) return;
    await init();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> showNow(ReminderMessage message) async {
    if (!isSupported) return;
    await init();
    await _plugin.show(
      id: testReminderId,
      title: message.title,
      body: message.body,
      notificationDetails: _details(message),
      payload: 'today',
    );
  }

  @override
  Future<String> manufacturer() async {
    if (!isSupported) return '';
    try {
      return await _device.invokeMethod<String>('manufacturer') ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<bool> openAutostartSettings() async {
    if (!isSupported) return false;
    try {
      return await _device.invokeMethod<bool>('openAutostart') ?? false;
    } catch (_) {
      return false;
    }
  }
}
