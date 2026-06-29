import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hatters_prime/controllers/membership_controller.dart';
import 'package:hatters_prime/screens/home_screen.dart';
import 'package:hatters_prime/screens/subscription_screen.dart';
import 'package:hatters_prime/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashController extends GetxController
    with GetSingleTickerProviderStateMixin {
  late AnimationController animationController;
  late Animation<double> logoScaleAnimation;
  late Animation<double> logoOpacityAnimation;
  late Animation<Offset> textSlideAnimation;
  late Animation<double> textOpacityAnimation;
  late Animation<double> loaderOpacityAnimation;

  @override
  void onInit() {
    super.onInit();
    
    animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.40, curve: Curves.elasticOut),
      ),
    );
    
    logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.20, curve: Curves.easeIn),
      ),
    );

    textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.30, 0.70, curve: Curves.easeOutCubic),
      ),
    );
    
    textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.30, 0.60, curve: Curves.easeIn),
      ),
    );

    loaderOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.70, 1.0, curve: Curves.easeIn),
      ),
    );

    animationController.forward();
    _initApp();
  }

  Future<void> _initApp() async {
    await Future.delayed(const Duration(milliseconds: 800));

    final membershipController = Get.put(MembershipController(), permanent: true);
    await membershipController.fetchSubscriptionStatus();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('wordpressAuthToken') ?? '';

      if (token.isEmpty) {
        TtsService.speak("User is not logged in.");
      } else {
        final userName = prefs.getString('wordpressUserName') ?? '';
        if (userName.isNotEmpty) {
          TtsService.speak("Welcome back, $userName.");
        } else {
          TtsService.speak("Welcome back.");
        }
      }
    } catch (e) {
      debugPrint("Error playing welcome TTS: $e");
    }

    _navigateToHome();
  }

  void _navigateToHome() {
    Get.off(
      () => const HomeScreen(),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 400),
    );
  }

  void navigateToMembership() {
    Get.off(
      () => const SubscriptionScreen(),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void onClose() {
    animationController.dispose();
    super.onClose();
  }
}
