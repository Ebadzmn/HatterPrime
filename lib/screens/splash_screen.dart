import 'package:flutter/material.dart';
import 'package:hatters_prime/constants.dart';
import 'package:hatters_prime/screens/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // Animation Definitions
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _loaderOpacityAnimation;

  @override
  void initState() {
    super.initState();
    // 1. Initialize Animation Controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000), // Total animation time
      vsync: this,
    );

    // 2. Define Staggered Animations
    // Logo pops in: 0% -> 40% of duration
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.elasticOut),
      ),
    );
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.20, curve: Curves.easeIn),
      ),
    );

    // Text slides up: 30% -> 70% of duration
    _textSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.30, 0.70, curve: Curves.easeOutCubic),
          ),
        );
    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.60, curve: Curves.easeIn),
      ),
    );

    // Loader fades in: 70% -> 100% of duration
    _loaderOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 1.0, curve: Curves.easeIn),
      ),
    );

    // 3. Start Animation
    _controller.forward();

    // 4. Start Initialization Logic
    _initApp();
  }

  Future<void> _initApp() async {
    // Determine minimum wait time (animation duration + buffer)
    final minWait = Future.delayed(const Duration(milliseconds: 2500));

    // Simulate other async tasks here (e.g., Auth check, Data prefetch)
    // await authService.checkLogin();
    // await dataService.prefetch();

    // Wait for both animation time and tasks
    await minWait;

    if (mounted) {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Keep it clean/premium
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO
                Opacity(
                  opacity: _logoOpacityAnimation.value,
                  child: Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(
                          25,
                        ), // Softer corners
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.store_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // TEXT
                SlideTransition(
                  position: _textSlideAnimation,
                  child: FadeTransition(
                    opacity: _textOpacityAnimation,
                    child: const Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800, // Extra bold
                        letterSpacing: 1.5,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // LOADER
                FadeTransition(
                  opacity: _loaderOpacityAnimation,
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
        ),
      ),
    );
  }
}
