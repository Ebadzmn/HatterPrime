import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/membership_controller.dart';

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the existing membership controller
    final MembershipController controller = Get.put(MembershipController());
    final Color primaryColor = const Color(0xFF005E41);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(primaryColor),
                const SizedBox(height: 32),
                _buildFeatures(primaryColor),
                const SizedBox(height: 32),
                _buildPlans(controller, primaryColor),
                const SizedBox(height: 32),
                _buildCallToAction(controller, primaryColor),
                const SizedBox(height: 32),
                _buildFooterLinks(),
                const SizedBox(height: 24),
                _buildLegalNotes(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    return Column(
      children: [
        Container(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.workspace_premium, size: 40, color: primaryColor),
        ),
        const SizedBox(height: 24),
        const Text(
          "Get Premium Access",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "Unlock all features and enjoy an ad-free experience",
          style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.4),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatures(Color primaryColor) {
    return Column(
      children: [
        _buildFeatureRow(
          Icons.all_inclusive,
          "Unlimited access to all content",
          primaryColor,
        ),
        _buildFeatureRow(
          Icons.block,
          "No ads, completely uninterrupted",
          primaryColor,
        ),
        _buildFeatureRow(
          Icons.support_agent,
          "Priority 24/7 customer support",
          primaryColor,
        ),
        _buildFeatureRow(
          Icons.star_border,
          "Exclusive premium features",
          primaryColor,
        ),
      ],
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlans(MembershipController controller, Color primaryColor) {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _buildPlanCard(
              controller: controller,
              primaryColor: primaryColor,
              planIndex: 1, // 1 maps to Monthly in MembershipController
              title: "Monthly",
              price: "\$20",
              duration: "1 month",
              isSelected: controller.selectedPlan.value == 1,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildPlanCard(
              controller: controller,
              primaryColor: primaryColor,
              planIndex: 2, // 2 maps to Yearly in MembershipController
              title: "Yearly",
              price: "\$200",
              duration: "1 year",
              isSelected: controller.selectedPlan.value == 2,
              recommendedLabel: "Best Value",
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required MembershipController controller,
    required Color primaryColor,
    required int planIndex,
    required String title,
    required String price,
    required String duration,
    required bool isSelected,
    String? recommendedLabel,
  }) {
    return GestureDetector(
      onTap: () => controller.selectPlan(planIndex),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? primaryColor : Colors.grey[200]!,
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: primaryColor.withOpacity(0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? primaryColor : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (recommendedLabel != null)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    recommendedLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCallToAction(
    MembershipController controller,
    Color primaryColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => ElevatedButton(
            onPressed:
                (controller.selectedPlan.value == 0 ||
                    controller.isPurchasing.value)
                ? null
                : () => controller.purchaseSelectedPlan(),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(vertical: 18),
              elevation: controller.selectedPlan.value == 0 ? 0 : 4,
              shadowColor: primaryColor.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: controller.isPurchasing.value
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    "Subscribe Now",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            if (controller.isPurchasing.value == false) {
              controller.restorePurchases();
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            "Restore Purchase",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () async {
            final Uri url = Uri.parse(
              'https://hattersprime.com/privacy-policy/',
            );
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Text(
            "Privacy Policy",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            "|",
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ),
        GestureDetector(
          onTap: () async {
            final Uri url = Uri.parse(
              'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
            );
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Text(
            "Terms of Use",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegalNotes() {
    return Text(
      "Payment will be charged to your Apple ID account at confirmation of purchase. "
      "Subscription automatically renews unless auto-renew is turned off at least "
      "24 hours before the end of the current period.",
      style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.5),
      textAlign: TextAlign.center,
    );
  }
}
