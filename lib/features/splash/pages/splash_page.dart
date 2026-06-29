import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hatters_prime/constants.dart';
import 'package:hatters_prime/features/splash/controllers/splash_controller.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: GetBuilder<SplashController>(
          builder: (controller) {
            return AnimatedBuilder(
              animation: controller.animationController,
              builder: (context, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LOGO
                    Opacity(
                      opacity: controller.logoOpacityAnimation.value,
                      child: Transform.scale(
                        scale: controller.logoScaleAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: Image.asset(
                              'assets/hatlogo.jpeg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // TEXT
                    SlideTransition(
                      position: controller.textSlideAnimation,
                      child: FadeTransition(
                        opacity: controller.textOpacityAnimation,
                        child: const Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // LOADER
                    FadeTransition(
                      opacity: controller.loaderOpacityAnimation,
                      child: const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black,
                          backgroundColor: Color(0xFFEEEEEE),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
