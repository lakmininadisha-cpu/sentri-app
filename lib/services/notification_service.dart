import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// A small wrapper around flutter_local_notifications so the rest of
// the app doesn't need to deal with the setup boilerplate directly.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    // Newer versions of this package require initialize()'s settings
    // to be passed as a named parameter rather than positionally.
    await _plugin.initialize(settings: initSettings);
    _isInitialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sentri_alerts',
      'Sentri Alerts',
      channelDescription: 'Reminders about items you might be forgetting',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    // Same change here — show() now takes everything as named
    // parameters instead of positional arguments.
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}