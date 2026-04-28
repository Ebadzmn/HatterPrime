import 'package:get/get.dart';
import '../models/purchase_details.dart';
import '../services/subscription_service.dart';

class SubscriptionController extends GetxController {
  final SubscriptionService _subscriptionService = SubscriptionService();

  // Reactive states
  var isLoading = false.obs;
  var isSubscribed = false.obs;
  var expiryDate = Rxn<DateTime>();
  var errorMessage = ''.obs;

  Future<void> handlePurchaseSuccess(PurchaseDetails purchase) async {
    // 1. Never unlock subscription before API success
    // Show loading state
    isLoading.value = true;
    errorMessage.value = '';

    try {
      // 2. Call API to verify purchase and send to backend
      final response = await _subscriptionService.verifyPurchase(purchase);

      if (response.status == 'active') {
        // 3. Backend verified, update local state
        isSubscribed.value = true;
        expiryDate.value = response.expiresAt;
        
        // Premium features are now unlocked since isSubscribed is true
        Get.snackbar('Success', 'Subscription activated successfully!');
      } else {
        // Handle other non-active statuses
        isSubscribed.value = false;
        errorMessage.value = 'Subscription status: ${response.status}';
        Get.snackbar('Error', 'Failed to activate subscription.', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      // 4. On Error, do not unlock features
      isSubscribed.value = false;
      errorMessage.value = 'Failed to verify subscription: $e';
      Get.snackbar('Error', errorMessage.value, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  void resetError() {
    errorMessage.value = '';
  }
}
