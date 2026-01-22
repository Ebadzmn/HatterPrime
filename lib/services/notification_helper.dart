import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hatters_prime/firebase_options.dart';

// Top-level function for background handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  static const AndroidNotificationChannel _notificationChannel =
      AndroidNotificationChannel(
    'hatters_prime_general',
    'General Notifications',
    description: 'General updates and announcements',
    importance: Importance.high,
  );

  static Future<void> initialize(BuildContext context) async {
    await _setupNotifications(context);
  }

  static String _resolveTitle(RemoteMessage message) {
    return message.notification?.title ?? message.data['title']?.toString() ?? '';
  }

  static String _resolveBody(RemoteMessage message) {
    return message.notification?.body ?? message.data['body']?.toString() ?? '';
  }

  static String _sanitizeDatabaseKey(String value) {
    return value.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
  }

  static FirebaseDatabase? _resolveDatabase() {
    final databaseUrl = DefaultFirebaseOptions.currentPlatform.databaseURL;
    if (databaseUrl == null || databaseUrl.isEmpty) {
      debugPrint('Realtime Database URL missing, skipping token save.');
      return null;
    }
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseUrl,
    );
  }

  static Future<void> _saveTokenToDatabase(String token) async {
    try {
      final database = _resolveDatabase();
      if (database == null) {
        return;
      }
      final ref = database.ref('fcm_tokens');
      final key = _sanitizeDatabaseKey(token);
      await ref.child(key).set({
        'token': token,
        'updatedAt': ServerValue.timestamp,
      });
      debugPrint('FCM Token saved to database successfully.');
    } catch (error) {
      debugPrint('FCM token save failed: $error');
    }
  }

  static Future<String?> _fetchFcmTokenWithRetry(FirebaseMessaging messaging) async {
    String? token;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          return token;
        }
      } catch (e) {
        debugPrint('Error fetching token attempt $attempt: $e');
      }
      await Future.delayed(const Duration(seconds: 2));
    }
    return token;
  }

  static Future<void> _registerForBroadcastMessaging(BuildContext context) async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request permission again just in case
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM Auth Status: ${settings.authorizationStatus}');

      await messaging.setAutoInitEnabled(true);
      
      final token = await _fetchFcmTokenWithRetry(messaging);
      
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _saveTokenToDatabase(token);
        
        // DEBUG: Show FCM Token in a dialog to confirm generation
        if (context.mounted) {
           // Only show debug dialog in debug mode or if requested.
           // For now, we will show a SnackBar to confirm success to the user.
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: Text('Notification Setup Success! Token: ${token.substring(0, 6)}...'),
               duration: const Duration(seconds: 2),
             ),
           );
        }
      } else {
        debugPrint('FCM token not available on Android yet.');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate FCM Token. Check internet?')),
          );
        }
      }
      
      await messaging.subscribeToTopic('all_users');
      
      messaging.onTokenRefresh.listen((token) {
        debugPrint('FCM Token Refreshed: $token');
        _saveTokenToDatabase(token);
      });
    } catch (error) {
      debugPrint('FCM setup failed: $error');
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('FCM setup failed: $error')),
          );
      }
    }
  }

  static Future<void> _setupNotifications(BuildContext context) async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {},
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_notificationChannel);

    // Request Android 13+ permission (flutter_local_notifications)
    try {
      final androidPermissionGranted =
          await androidPlugin?.requestNotificationsPermission();
      debugPrint('Android notification permission: $androidPermissionGranted');
    } catch (e) {
      debugPrint('Android permission request failed: $e');
    }

    // Request FCM permission
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('FCM permission request failed: $e');
    }

    // Always try to register for token/messaging, even if permission is denied
    if (context.mounted) {
      await _registerForBroadcastMessaging(context);
    }

    FirebaseMessaging.onMessage.listen((message) async {
      final title = _resolveTitle(message);
      final body = _resolveBody(message);
      if (title.isEmpty && body.isEmpty) {
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        _notificationChannel.id,
        _notificationChannel.name,
        channelDescription: _notificationChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails();

      await _localNotifications.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened: ${message.messageId}');
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('Notification opened from terminated: ${initialMessage.messageId}');
    }
  }
}
