import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hatters_prime/constants.dart';
import 'package:hatters_prime/services/notification_helper.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';
import 'package:hatters_prime/controllers/membership_controller.dart';
import 'package:hatters_prime/screens/subscription_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _isConnected = true;
  bool _canGoBack = false;
  double _progress = 0;
  bool _shouldCheckAuthToken = false;
  Timer? _tokenCheckTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _hasVisitedSignup = false;

  final InAppWebViewSettings _settings = InAppWebViewSettings(
    // Update 1
    // Enable JavaScript
    javaScriptEnabled: true,
    // Enable DOM storage & Database (Important for auth tokens)
    domStorageEnabled: true,
    databaseEnabled: true,
    // Enable cache
    cacheEnabled: true,
    // Allow mixed content (http in https)
    // mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
    // Handle new windows / tabs inside the app
    supportMultipleWindows: false,
    javaScriptCanOpenWindowsAutomatically: true,
    // Disable zoom for cleaner look (optional)
    supportZoom: true,
    // User agent: Mimic a real mobile browser to prevent bot detection
    userAgent:
        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Mobile Safari/537.36",
    // Allow file access
    allowFileAccess: true,
    allowContentAccess: true,
    // Cookie Config (CRITICAL FOR LOGIN)
    thirdPartyCookiesEnabled: true,
    sharedCookiesEnabled: true,
    // Clear cache on start? (optional)
    clearCache: false,
    // Use wide viewport
    useWideViewPort: true,
    // Load with overview mode
    loadWithOverviewMode: true,
    // Allow universal access from file URLs
    allowUniversalAccessFromFileURLs: true,
    // Transparent background
    transparentBackground: true,
    // CRITICAL: Ensure tablets (especially iPads) render in mobile mode so touch events register properly
    preferredContentMode: UserPreferredContentMode.MOBILE,
  );

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    // Ensure notifications are setup even if SplashScreen skipped it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NotificationHelper.initialize(context);
      }
    });
  }

  @override
  void dispose() {
    _tokenCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _webViewController = null;
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasConnection = connectivityResult.any(
      (result) => result != ConnectivityResult.none,
    );

    setState(() {
      _isConnected = hasConnection;
    });

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      if (!mounted) return;
      
      final hasConnection = results.any(
        (result) => result != ConnectivityResult.none,
      );

      setState(() {
        _isConnected = hasConnection;
      });

      if (_isConnected && _webViewController != null) {
        try {
          await _webViewController!.reload();
        } catch (e) {
          debugPrint('Error reloading webview: $e');
        }
      }
    });
  }

  Future<void> _checkCanGoBack() async {
    if (_webViewController != null) {
      final canGoBack = await _webViewController!.canGoBack();
      if (mounted) {
        setState(() {
          _canGoBack = canGoBack;
        });
      }
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      debugPrint('Failed to launch external url: $url');
    }
  }

  void _startTokenCheckTimer() {
    if (!_shouldCheckAuthToken) {
      return;
    }
    if (_tokenCheckTimer?.isActive ?? false) {
      return;
    }
    _tokenCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkAndStoreWordPressToken();
    });
  }

  Future<void> _checkAndStoreWordPressToken() async {
    if (_webViewController == null) {
      return;
    }
    try {
      final result = await _webViewController!.evaluateJavascript(
        source: 'window.APP_AUTH && window.APP_AUTH.token',
      );
      final token = _normalizeTokenResult(result);
      
      final prefs = await SharedPreferences.getInstance();
      final existingToken = prefs.getString('wordpressAuthToken');

      if (token == null || token.isEmpty) {
        // Logout case: If we had a token but now it's gone from webview
        if (existingToken != null && existingToken.isNotEmpty) {
          debugPrint('🚪 Logout detected in WebView. Clearing local token.');
          await prefs.remove('wordpressAuthToken');
          _hasVisitedSignup = false;
          
          final membershipController = Get.find<MembershipController>();
          membershipController.isSubscribed.value = false;
          membershipController.subscriptionPlan.value = '';
          membershipController.subscriptionExpiry.value = null;
        }
        return;
      }

      // Login/Sync case: If token is different or we don't have one locally
      if (token != existingToken) {
        debugPrint('🔑 New/Refreshed WordPress Token detected: $token');
        await prefs.setString('wordpressAuthToken', token);

        // Real-time validation after login
        final membershipController = Get.find<MembershipController>();
        await membershipController.fetchSubscriptionStatus();

        if (_hasVisitedSignup && !membershipController.isSubscribed.value) {
          debugPrint('🎉 Signup success! Redirecting to subscription page...');
          _hasVisitedSignup = false; // Reset to avoid double triggering
          Get.to(() => const SubscriptionScreen());
        }
      }

      // Stop aggressive checking once sync is achieved for this page load
      _shouldCheckAuthToken = false;
      _tokenCheckTimer?.cancel();
      _tokenCheckTimer = null;
    } catch (e) {
      debugPrint('Error retrieving WordPress token: $e');
    }
  }

  String? _normalizeTokenResult(dynamic result) {
    if (result == null) {
      return null;
    }
    if (result is String) {
      var value = result.trim();
      if (value.isEmpty ||
          value == 'null' ||
          value == 'undefined' ||
          value == '"null"' ||
          value == '"undefined"') {
        return null;
      }
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.substring(1, value.length - 1).trim();
      }
      if (value.isEmpty ||
          value == 'null' ||
          value == 'undefined') {
        return null;
      }
      return value;
    }
    final value = result.toString().trim();
    if (value.isEmpty ||
        value == 'null' ||
        value == 'undefined') {
      return null;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    // Show no internet screen
    if (!_isConnected) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 24),
                Text(
                  "No Internet Connection",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Please check your connection and try again.",
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _checkConnectivity,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main WebView screen
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_webViewController != null &&
            await _webViewController!.canGoBack()) {
          await _webViewController!.goBack();
        } else {
          if (context.mounted) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        // No AppBar at the top
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(AppConstants.webUrl)),
                initialSettings: _settings,
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onUpdateVisitedHistory:
                    (controller, url, androidIsReload) async {
                  await _checkCanGoBack();
                  await _handleSportsPageAccess(controller, url);
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading = true;
                  });
                  _checkCanGoBack();
                  if (url != null && url.toString().contains('/join-now')) {
                    _hasVisitedSignup = true;
                    debugPrint('📝 User visited signup page: $url');
                  }
                  _handleSportsPageAccess(controller, url);
                },
                onLoadStop: (controller, url) {
                  setState(() {
                    _isLoading = false;
                  });
                  _checkCanGoBack();
                  
                  // Always check auth state on page load stop to ensure sync
                  _shouldCheckAuthToken = true;
                  _startTokenCheckTimer();
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100;
                  });
                },
                onReceivedError: (controller, request, error) {
                  debugPrint('WebView Error: ${error.description}');
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri != null) {
                    final urlString = uri.toString();
                    
                    // Intercept the /join-now/ link and redirect internally
                    if (urlString.startsWith('https://hattersprime.com/join-now') &&
                        !urlString.startsWith('https://hattersprime.com/join-now-app')) {
                      await controller.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri('https://hattersprime.com/join-now-app/'),
                        ),
                      );
                      return NavigationActionPolicy.CANCEL;
                    }

                    // Check subscription requirement for sports pages
                    final cleanPath = uri.path.replaceAll('//', '/');
                    final isSportsPage = cleanPath.startsWith('/baseball') ||
                        cleanPath.startsWith('/football') ||
                        cleanPath.startsWith('/mens-basketball') ||
                        cleanPath.startsWith('/womens-basketball');

                    if (isSportsPage) {
                      final membershipController = Get.find<MembershipController>();
                      if (membershipController.isSubscribed.value) {
                        return NavigationActionPolicy.ALLOW;
                      } else {
                        Get.snackbar(
                          'Subscription Required',
                          'Please subscribe to access this content.',
                          backgroundColor: const Color(0xFFC62828),
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                        Get.to(() => const SubscriptionScreen());
                        return NavigationActionPolicy.CANCEL;
                      }
                    }

                    final isMembership =
                        urlString.startsWith('https://hattersprime.com/memberships');
                    if (isMembership) {
                      final membershipController = Get.find<MembershipController>();
                      if (membershipController.isSubscribed.value) {
                        Get.snackbar(
                          'Active Subscription',
                          'Your subscription is currently active.',
                          backgroundColor: const Color(0xFF005E41),
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      } else {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('wordpressAuthToken');
                        if (token != null && token.isNotEmpty) {
                          Get.to(() => const SubscriptionScreen());
                        } else {
                          await controller.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri('${AppConstants.webUrl}/log-in/'),
                            ),
                          );
                        }
                      }
                      return NavigationActionPolicy.CANCEL;
                    }
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onCreateWindow: (controller, createWindowAction) async {
                  if (createWindowAction.request.url != null) {
                    await controller.loadUrl(
                      urlRequest: createWindowAction.request,
                    );
                  }
                  return false;
                },
              ),

              // Custom Gradient Loading Bar (Non-intrusive, "Smart")
              if (_isLoading && _progress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: _progress),
                    duration: const Duration(milliseconds: 200),
                    builder: (context, value, _) {
                      return Container(
                        height: 3, // Very thin and sleek
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black,
                              Colors.blueGrey.shade800, // Gradient flow
                              Colors.black,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                        width: MediaQuery.of(context).size.width * value,
                      );
                    },
                  ),
                ),

              // Initial Load Center Logo Pulse
              if (_isLoading && _progress < 0.2)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Stack(
                children: [
                  // App Title (Absolute Center)
                  const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 40),
                        Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Buttons (Left & Right)
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left Side (Back + Menu)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Back Button
                            _buildBottomBarButton(
                              icon: Icons.arrow_back_ios_new,
                              label: "Back",
                              onTap: () async {
                                if (_webViewController != null && await _webViewController!.canGoBack()) {
                                  _webViewController!.goBack();
                                }
                              },
                              isEnabled: _canGoBack,
                            ),
                            const SizedBox(width: 12),
                            // Menu Button
                            _buildBottomBarButton(
                              icon: Icons.menu,
                              label: "Menu",
                              onTap: _showMenuBottomSheet,
                            ),
                          ],
                        ),

                        // Right Side (Refresh)
                        _buildBottomBarButton(
                          icon: Icons.refresh,
                          label: "Refresh",
                          onTap: () => _webViewController?.reload(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBarButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isEnabled = true,
  }) {
    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.grey[100] : Colors.grey[50],
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isEnabled ? Colors.black : Colors.grey[300],
        ),
      ),
    );
  }

  void _navigateToSportPage(String path) {
    final membershipController = Get.find<MembershipController>();
    if (membershipController.isSubscribed.value) {
      _webViewController?.loadUrl(
        urlRequest: URLRequest(
          url: WebUri('${AppConstants.webUrl}${path.startsWith('/') ? path.substring(1) : path}'),
        ),
      );
    } else {
      Get.snackbar(
        'Subscription Required',
        'Please subscribe to access this content.',
        backgroundColor: const Color(0xFFC62828),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      Get.to(() => const SubscriptionScreen());
    }
  }

  Future<void> _handleSportsPageAccess(InAppWebViewController controller, WebUri? url) async {
    if (url == null) return;
    
    final cleanPath = url.path.replaceAll('//', '/');
    final isSportsPage = cleanPath.startsWith('/baseball') ||
        cleanPath.startsWith('/football') ||
        cleanPath.startsWith('/mens-basketball') ||
        cleanPath.startsWith('/womens-basketball');

    if (isSportsPage) {
      final membershipController = Get.find<MembershipController>();
      if (!membershipController.isSubscribed.value) {
        debugPrint('🚫 Access denied to sports page: $url. Redirecting to subscription page...');
        
        // Prevent the load/view from continuing by going back or loading home page
        if (await controller.canGoBack()) {
          await controller.goBack();
        } else {
          await controller.loadUrl(
            urlRequest: URLRequest(
              url: WebUri(AppConstants.webUrl),
            ),
          );
        }

        // Show warning snackbar
        Get.snackbar(
          'Subscription Required',
          'Please subscribe to access this content.',
          backgroundColor: const Color(0xFFC62828),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );

        // Go to native subscription page
        Get.to(() => const SubscriptionScreen());
      }
    }
  }

  void _showMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85, // Take 85% height
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A3A4A), // Dark teal
              Color(0xFF0D2833), // Darker teal
              Color(0xFF081C24), // Almost black
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle for affordance
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Reusing existing drawer content structure
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                AppConstants.appName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Action Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.home_outlined, 'Home', () {
                    Navigator.pop(context);
                    _webViewController?.loadUrl(
                      urlRequest: URLRequest(url: WebUri(AppConstants.webUrl)),
                    );
                  }),
                  _buildActionButton(Icons.settings_outlined, 'Settings', () {
                    Navigator.pop(context);
                  }),
                  _buildActionButton(Icons.close, 'Close', () {
                    Navigator.pop(context);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.2), height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildMenuItem(
                    Icons.info_outline,
                    'ABOUT',
                    onTap: () {
                      Navigator.pop(context);
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri('${AppConstants.webUrl}/about'),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.card_membership,
                    'MEMBERSHIPS',
                    onTap: () async {
                      Navigator.pop(context);
                      final controller = Get.find<MembershipController>();
                      if (controller.isSubscribed.value) {
                        Get.snackbar(
                          'Active Subscription',
                          'Your subscription is currently active.',
                          backgroundColor: const Color(0xFF005E41),
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      } else {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('wordpressAuthToken');
                        if (token != null && token.isNotEmpty) {
                          Get.to(() => const SubscriptionScreen());
                        } else {
                          _webViewController?.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri('${AppConstants.webUrl}/log-in/'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _buildMenuItem(
                    Icons.person_add_alt_1_outlined,
                    'JOIN NOW',
                    onTap: () {
                      Navigator.pop(context);
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri('https://hattersprime.com/join-now-app/'),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.app_registration,
                    'REGISTER',
                    onTap: () {
                      Navigator.pop(context);
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri('https://hattersprime.com/join-now-app/'),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.contact_support_outlined,
                    'CONTACT',
                    onTap: () {
                      Navigator.pop(context);
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri('${AppConstants.webUrl}/contact'),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.login,
                    'MEMBER LOGIN',
                    onTap: () {
                      Navigator.pop(context);
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri('${AppConstants.webUrl}/log-in/'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16), // Spacer for grouping
                  _buildMenuItem(
                    Icons.home_work_outlined,
                    'MEMBERS HOME',
                    onTap: () {
                      Navigator.pop(context);
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri('${AppConstants.webUrl}/members-home'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16), // Spacer for grouping
                  _buildMenuItem(
                    Icons.sports_baseball_outlined,
                    'BASEBALL HOME',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToSportPage('baseball');
                    },
                  ),
                  _buildMenuItem(
                    Icons.sports_football_outlined,
                    'FOOTBALL HOME',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToSportPage('football');
                    },
                  ),
                  _buildMenuItem(
                    Icons.sports_basketball_outlined,
                    'MENS BASKETBALL',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToSportPage('mens-basketball');
                    },
                  ),
                  _buildMenuItem(
                    Icons.sports_basketball,
                    'WOMENS BASKETBALL',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToSportPage('womens-basketball');
                    },
                  ),
                  _buildMenuItem(
                    Icons.golf_course_outlined,
                    'GOLF HOME',
                    onTap: () {
                      Navigator.pop(context);
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri('${AppConstants.webUrl}/golf'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16), // Spacer for grouping
                  _buildMenuItem(
                    Icons.logout,
                    'LOG IN/OUT',
                    onTap: () {
                      Navigator.pop(context);
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri('${AppConstants.webUrl}/log-in/'),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    Icons.account_circle_outlined,
                    'MEMBER ACCOUNT',
                    onTap: () {
                      Navigator.pop(context);
                      _webViewController?.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri('${AppConstants.webUrl}/account'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 48), // Bottom padding
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white.withOpacity(0.9), size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }
}
