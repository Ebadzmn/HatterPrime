import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hatters_prime/controllers/membership_controller.dart';

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the controller
    final MembershipController controller = Get.put(MembershipController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Membership', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header similar to image
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF005E41), // Deep Green from Hatter Insider
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'HATTER INSIDER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    const Text(
                      'Choose your plan:',
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Basic Plan Card
                    Obx(() => _buildPlanCard(
                      title: 'Basic Plan',
                      price: '20',
                      description: 'Small plan (Basic)',
                      icon: Icons.star_border_rounded,
                      isSelected: controller.selectedPlan.value == 1,
                      onTap: () => controller.selectPlan(1),
                    )),
                    
                    const SizedBox(height: 20),
                    
                    // Premium Plan Card
                    Obx(() => _buildPlanCard(
                      title: 'Premium Plan',
                      price: '200',
                      description: 'Highlighted plan (Premium)',
                      icon: Icons.diamond_outlined,
                      isSelected: controller.selectedPlan.value == 2,
                      isPremium: true,
                      onTap: () => controller.selectPlan(2),
                    )),
                    
                    const SizedBox(height: 32),

                    // Includes Section
                    const Text(
                      'Includes:',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildFeatureItem('Multi-sport access to all members-only content', isFirst: true),
                    _buildFeatureItem('Practice & workout footage, scrimmages, and drills'),
                    _buildFeatureItem('Player & coach interviews and film-room insights'),
                    _buildFeatureItem('Weekly team updates and new episode drops by sport'),
                    _buildFeatureItem('Behind-the-scenes travel, culture, and game-week features'),
                    _buildFeatureItem('Archive access with sport filters (Baseball, Football, MBB, WBB, Golf)', isLast: true),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // Join Now Button Pinned to Bottom
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  )
                ]
              ),
              child: Obx(() => ElevatedButton(
                onPressed: (controller.selectedPlan.value == 0 || controller.isPurchasing.value)
                  ? null 
                  : () {
                      controller.purchaseSelectedPlan();
                    },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005E41),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  minimumSize: const Size(double.infinity, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: controller.selectedPlan.value == 0 ? 0 : 4,
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
                        'JOIN NOW',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text, {bool isFirst = false, bool isLast = false}) {
    return Column(
      children: [
        if (isFirst) Divider(color: Colors.grey.shade300, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle, 
                color: Color(0xFF005E41),
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(color: Colors.grey.shade300, height: 1),
        if (isLast) Divider(color: Colors.grey.shade300, height: 1), // also line at very bottom
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isPremium = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FAF5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF005E41) : Colors.grey.shade200,
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF005E41).withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF005E41).withOpacity(0.1) : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF005E41) : Colors.grey.shade500,
                size: isPremium ? 32 : 28,
              ),
            ),
            const SizedBox(width: 20),
            
            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isPremium ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF005E41) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            // Price & Check
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? const Color(0xFF005E41) : Colors.black87,
                      ),
                    ),
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: isPremium ? 32 : 28,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? const Color(0xFF005E41) : Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (isSelected) ...[
                  const SizedBox(height: 8),
                  const Icon(
                    Icons.check_circle_rounded, 
                    color: Color(0xFF005E41),
                    size: 24,
                  ),
                ] else const SizedBox(height: 32), // Placeholder to keep height consistent
              ],
            ),
          ],
        ),
      ),
    );
  }
}
