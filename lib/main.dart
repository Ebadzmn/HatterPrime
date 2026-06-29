import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hatters_prime/firebase_options.dart';
import 'package:hatters_prime/features/splash/bindings/splash_binding.dart';
import 'package:hatters_prime/features/splash/pages/splash_page.dart';
import 'package:hatters_prime/services/notification_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        debugPrint('Firebase already initialized.');
      } else {
        debugPrint('Firebase initialization failed: $e');
      }
    }
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Notification setup moved to SplashScreen to ensure valid context for dialogs
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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
      initialBinding: SplashBinding(),
      home: const SplashPage(),
    );
  }
}
