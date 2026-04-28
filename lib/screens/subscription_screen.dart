import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/subscription_controller.dart';
import '../models/purchase_details.dart';

class SubscriptionScreen extends StatelessWidget {
  SubscriptionScreen({Key? key}) : super(key: key);

  final SubscriptionController controller = Get.put(SubscriptionController());

  // Dummy method to simulate a native purchase success callback
  void _simulatePurchaseSuccess() {
    final mockPurchase = PurchaseDetails(
      productId: 'monthly_plan_1',
      transactionId: 'txn_${DateTime.now().millisecondsSinceEpoch}',
      purchaseDate: DateTime.now().toIso8601String(),
      expiryDate: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
    );
    controller.handlePurchaseSuccess(mockPurchase);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Subscription'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Verifying purchase securely...'),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              if (controller.isSubscribed.value) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'You are Subscribed! 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your subscription expires on:\n${_formatDate(controller.expiryDate.value)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Premium features unlocked!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.blue),
                ),
              ] else ...[
                const Icon(Icons.star_border, color: Colors.orange, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Unlock Premium Features',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _simulatePurchaseSuccess,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Buy Monthly Subscription', style: TextStyle(fontSize: 18)),
                ),
                if (controller.errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ],
          );
        }),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateFormat.yMMMMd().format(date);
  }
}
