import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hatters_prime/screens/home_screen.dart';
import '../controllers/membership_controller.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the globally initialized controller
    final MembershipController controller = Get.find<MembershipController>();
    const Color primaryColor = Color(0xFF005E41);

    // Auto-redirect if already subscribed (if not in purchasing flow)
    ever(controller.isSubscribed, (bool subscribed) {
      if (subscribed && !controller.isPurchasing.value) {
        Get.offAll(() => const HomeScreen());
      }
    });

    // Check once on build too
    if (controller.isSubscribed.value && !controller.isPurchasing.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAll(() => const HomeScreen());
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Premium Access',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => controller.restorePurchases(),
            child: const Text('Restore', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
      body: Obx(() {
        // 1. Loading State (Purchasing or Store Init)
        if (controller.isPurchasing.value || !controller.isStoreReady.value) {
          return _buildLoadingState(controller);
        }

        // 2. Success State
        if (controller.isSubscribed.value) {
          return _buildSubscribedView(controller, primaryColor);
        }

        // 3. Purchase Options State
        return _buildSubscriptionOptions(controller, primaryColor);
      }),
    );
  }

  Widget _buildLoadingState(MembershipController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF005E41)),
          const SizedBox(height: 24),
          Text(
            controller.isPurchasing.value 
                ? 'Processing your purchase...' 
                : 'Connecting to App Store...',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          if (controller.isPurchasing.value) ...[
            const SizedBox(height: 8),
            const Text(
              'Please do not close the app.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscribedView(MembershipController controller, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 100),
          const SizedBox(height: 32),
          const Text(
            'Welcome to Premium! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Your ${controller.subscriptionPlan.value} plan is now active.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => Get.offAll(() => const HomeScreen()),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Get Started',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionOptions(MembershipController controller, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 80),
          const SizedBox(height: 24),
          const Text(
            'Unlock Everything',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Access all tracking tools, detailed insights, and an ad-free experience.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 40),
          
          // Dynamic Plan Selection from Store
          Row(
            children: [
              Expanded(
                child: _buildPlanCard(
                  controller: controller,
                  title: 'Monthly',
                  planId: 1,
                  primaryColor: primaryColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPlanCard(
                  controller: controller,
                  title: 'Yearly',
                  planId: 2,
                  isPopular: true,
                  primaryColor: primaryColor,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          _buildFeatureItem(Icons.bolt, 'Real-time performance tracking'),
          _buildFeatureItem(Icons.analytics_outlined, 'Deep insight reports'),
          _buildFeatureItem(Icons.cloud_done_rounded, 'Cloud sync across devices'),
          
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => controller.purchaseSelectedPlan(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: primaryColor.withOpacity(0.4),
            ),
            child: const Text(
              'Continue to Checkout',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cancel anytime. Payment processed securely via Apple.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF005E41), size: 24),
          const SizedBox(width: 16),
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required MembershipController controller,
    required String title,
    required int planId,
    required Color primaryColor,
    bool isPopular = false,
  }) {
    // Try to get price from the store
    String price = planId == 1 ? '\$29.99' : '\$299.99'; // Default values
    
    if (controller.availableProducts.isNotEmpty) {
      try {
        final product = controller.availableProducts.firstWhere(
          (p) => p.id == (planId == 1 ? controller.monthlyId : controller.yearlyId)
        );
        price = product.price;
      } catch (_) {}
    }

    return Obx(() {
      final isSelected = controller.selectedPlan.value == planId;
      return GestureDetector(
        onTap: () => controller.selectPlan(planId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: isSelected
                ? [BoxShadow(color: primaryColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primaryColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    title == 'Yearly' ? '/year' : '/month',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              if (isPopular)
                Positioned(
                  top: -34,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SAVE 20%',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}
