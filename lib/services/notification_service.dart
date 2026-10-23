import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    // Default location, you might want to get local timezone dynamically if app goes global
    // tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); 

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // For iOS if added later
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // Request permissions for Android 13+
    _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
        
    _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    _isInitialized = true;
  }

  // Schedule a reminder for a specific date
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await init();
    
    // Only schedule if the time is in the future
    if (scheduledDate.isBefore(DateTime.now())) {
      debugPrint('Cannot schedule notification in the past: $scheduledDate');
      return;
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'financial_reminders_channel',
          'Financial Reminders',
          channelDescription: 'Notifications for upcoming financial payments',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // If we want daily at same time, but we set exact dates
      payload: payload,
    );
    debugPrint('Scheduled notification ID $id for $scheduledDate');
  }

  // Cancel a scheduled reminder
  Future<void> cancelReminder(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    debugPrint('Cancelled notification ID $id');
  }
  
  // Schedule Due Date and Overdue Notifications
  Future<void> scheduleFinancialReminder({
    required String reminderIdString, // UUID string
    required String title,
    required DateTime dueDate,
  }) async {
    // Generate an integer ID from the UUID (simple hash for local notifications)
    final int baseId = reminderIdString.hashCode;
    
    // 1. Due Date Notification (at 9 AM on the due date)
    DateTime dueNotificationTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
    // If it's already past 9 AM today, maybe schedule for next minute for testing, or skip
    if (dueNotificationTime.isBefore(DateTime.now())) {
       // If the due date is today, and it's past 9 AM, we might want to alert immediately or just rely on the UI.
       // For now, let's schedule it 2 mins from now if today is the due date
       if (dueDate.year == DateTime.now().year && dueDate.month == DateTime.now().month && dueDate.day == DateTime.now().day) {
           dueNotificationTime = DateTime.now().add(const Duration(minutes: 2));
       }
    }
    
    if (dueNotificationTime.isAfter(DateTime.now())) {
      await scheduleReminder(
        id: baseId,
        title: 'Payment Due Today: $title',
        body: 'Don\'t forget to make your payment today.',
        scheduledDate: dueNotificationTime,
        payload: reminderIdString,
      );
    }

    // 2. Overdue Notification (at 10 AM on the day AFTER due date)
    DateTime overdueTime = DateTime(dueDate.year, dueDate.month, dueDate.day + 1, 10, 0);
    if (overdueTime.isAfter(DateTime.now())) {
      await scheduleReminder(
        id: baseId + 1, // offset by 1 for overdue
        title: 'Overdue Payment: $title',
        body: 'You missed a payment yesterday. Please pay as soon as possible.',
        scheduledDate: overdueTime,
        payload: reminderIdString,
      );
    }
  }

  Future<void> cancelFinancialReminder(String reminderIdString) async {
    final int baseId = reminderIdString.hashCode;
    await cancelReminder(baseId);
    await cancelReminder(baseId + 1); // Cancel overdue as well
  }
}
