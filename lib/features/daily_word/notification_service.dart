import 'package:firebase_messaging/firebase_messaging.dart';

/// Placeholder notification service for daily reminders (FR-04).
///
/// For a production implementation you would likely combine FCM with a
/// local notifications plugin to schedule device-local alerts at the
/// user’s chosen time.
class NotificationService {
  NotificationService(this._messaging);

  final FirebaseMessaging _messaging;

  Future<void> requestPermission() async {
    await _messaging.requestPermission();
  }

  Future<void> initialize() async {
    // TODO: Configure FCM handlers, topics, etc.
  }
}

