import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles local notifications for:
/// - New chat messages
/// - Incoming calls (with sound)
/// - PTT activity alerts (someone is talking)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification IDs
  static const int _chatNotificationId = 1001;
  static const int _callNotificationId = 1002;
  static const int _pttNotificationId = 1003;

  // Channel IDs
  static const String _chatChannelId = 'cambocom_chat';
  static const String _callChannelId = 'cambocom_call';
  static const String _pttChannelId = 'cambocom_ptt';

  /// Initialize — must be called once at app start (e.g., in main() or HomeScreen.initState)
  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings);

    // Create notification channels (Android 8+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _chatChannelId,
          'សារជជែក',
          description: 'ការជូនដំណឹងពីសារ Chat ថ្មី',
          importance: Importance.high,
          playSound: true,
        ));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _callChannelId,
          'ការហៅទូរស័ព្ទ',
          description: 'ការជូនដំណឹងពីការហៅចូល',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _pttChannelId,
          'PTT Activity',
          description: 'ការជូនដំណឹងពី PTT',
          importance: Importance.defaultImportance,
          playSound: false,
        ));

    // Request notification permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  /// Show a notification for a new chat message.
  /// [sender] - display name of the sender
  /// [message] - message preview text
  Future<void> showChatNotification({
    required String sender,
    required String message,
  }) async {
    if (!_initialized) return;
    await _plugin.show(
      _chatNotificationId,
      '💬 $sender',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _chatChannelId,
          'សារជជែក',
          channelDescription: 'ការជូនដំណឹងពីសារ Chat ថ្មី',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
        ),
      ),
    );
  }

  /// Show a notification for an incoming call with max-priority + vibration.
  /// [callerName] - name of the person calling
  Future<void> showCallNotification({required String callerName}) async {
    if (!_initialized) return;
    final vibration = Int64List.fromList([0, 500, 200, 500]);
    await _plugin.show(
      _callNotificationId,
      '📞 មានការហៅចូល!',
      '$callerName កំពុងហៅ...',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannelId,
          'ការហៅទូរស័ព្ទ',
          channelDescription: 'ការជូនដំណឹងពីការហៅចូល',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          vibrationPattern: vibration,
          fullScreenIntent: true,
        ),
      ),
    );
  }

  /// Cancel the ongoing call notification (when call ends/rejected)
  Future<void> cancelCallNotification() async {
    await _plugin.cancel(_callNotificationId);
  }

  /// Show a brief PTT-activity notification (optional, low-priority)
  Future<void> showPttNotification({required String talkerName}) async {
    if (!_initialized) return;
    await _plugin.show(
      _pttNotificationId,
      '🗣️ $talkerName กำลังพูด',
      'แตะเพื่อตอบกลับ',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _pttChannelId,
          'PTT Activity',
          channelDescription: 'ការជូនដំណឹងពី PTT',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          playSound: false,
          enableVibration: false,
          ongoing: false,
          autoCancel: true,
        ),
      ),
    );
  }

  /// Cancel PTT notification
  Future<void> cancelPttNotification() async {
    await _plugin.cancel(_pttNotificationId);
  }
}
