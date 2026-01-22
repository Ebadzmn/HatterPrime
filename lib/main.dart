import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hatters_prime/firebase_options.dart';
import 'package:hatters_prime/screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel _notificationChannel =
    AndroidNotificationChannel(
  'hatters_prime_general',
  'General Notifications',
  description: 'General updates and announcements',
  importance: Importance.high,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

String _resolveTitle(RemoteMessage message) {
  return message.notification?.title ?? message.data['title']?.toString() ?? '';
}

String _resolveBody(RemoteMessage message) {
  return message.notification?.body ?? message.data['body']?.toString() ?? '';
}

String _sanitizeDatabaseKey(String value) {
  return value.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
}

Future<void> _saveTokenToDatabase(String token) async {
  final ref = FirebaseDatabase.instance.ref('fcm_tokens');
  final key = _sanitizeDatabaseKey(token);
  await ref.child(key).set({
    'token': token,
    'updatedAt': ServerValue.timestamp,
  });
}

Future<void> _registerForBroadcastMessaging() async {
  final messaging = FirebaseMessaging.instance;
  final token = await messaging.getToken();
  if (token != null) {
    debugPrint('FCM Token: $token');
    await _saveTokenToDatabase(token);
  }
  await messaging.subscribeToTopic('all_users');
  messaging.onTokenRefresh.listen((token) {
    debugPrint('FCM Token Refreshed: $token');
    _saveTokenToDatabase(token);
  });
}

Future<void> _setupNotifications() async {
  const initializationSettingsAndroid =
      AndroidInitializationSettings('ic_launcher');
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
  await androidPlugin?.requestNotificationsPermission();

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  await _registerForBroadcastMessaging();

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
      icon: 'ic_launcher',
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _setupNotifications();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Hatter's Prime",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
      ),
      home: const SplashScreen(),
    );
  }
}
