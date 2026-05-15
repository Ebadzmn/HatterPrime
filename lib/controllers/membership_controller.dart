import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hatters_prime/constants.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class MembershipController extends GetxController {
  // 1 for basic (monthly), 2 for premium (yearly)
  var selectedPlan = 2.obs;
  var isPurchasing = false.obs;
  var isStoreReady = false.obs;
  var storeMessage = RxnString();

  // Subscription State
  var isSubscribed = false.obs;
  var subscriptionPlan = ''.obs;
  var subscriptionExpiry = RxnString();

  Future<void> fetchSubscriptionStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('wordpressAuthToken') ?? '';

      if (token.isEmpty) {
        isSubscribed.value = false;
        return;
      }

      final String nocache = DateTime.now().millisecondsSinceEpoch.toString();
      final url = Uri.parse(
        '${AppConstants.webUrl}wp-json/imc/v1/subscription-status?nocache=$nocache',
      );
      debugPrint('\n======= 🔄 FETCH SUBSCRIPTION STATUS =======');
      debugPrint('URL: $url');
      debugPrint(
        'Headers: Authorization: Bearer ${token.length > 5 ? token.substring(0, 5) : token}***',
      );

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('============================================\n');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String status = data['status'] ?? '';
        final String? expiresAtStr = data['expires_at'];

        bool isActive = status == 'active';

        // Flow Logic: Expiry Validation
        if (isActive && expiresAtStr != null && expiresAtStr.isNotEmpty) {
          try {
            final DateTime expiryDate = DateTime.parse(expiresAtStr);
            final DateTime now = DateTime.now();
            final DateTime today = DateTime(now.year, now.month, now.day);
            final DateTime normalizedExpiry = DateTime(
              expiryDate.year,
              expiryDate.month,
              expiryDate.day,
            );

            // If the current date is strictly AFTER the expires_at date: Treat as expired
            if (today.isAfter(normalizedExpiry)) {
              isActive = false;
              debugPrint('Subscription treats as expired: $expiresAtStr');
            }
          } catch (e) {
            debugPrint('Error parsing expiry date: $e');
          }
        }

        isSubscribed.value = isActive;
        subscriptionPlan.value = data['plan'] ?? '';
        subscriptionExpiry.value = expiresAtStr;
      } else {
        isSubscribed.value = false;
      }
    } catch (e) {
      debugPrint('Error fetching subscription status: $e');
      isSubscribed.value = false;
    }
  }

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Product IDs matching the requirement
  final String monthlyId = 'com.hattersgroup.monthly';
  final String yearlyId = 'com.hatterscollectivegroup.yearly';
  // final String yearlyId = 'com.HattersCollectiveGroup.Yearly';

  var availableProducts = <ProductDetails>[].obs;

  String get storeName => Platform.isIOS ? 'App Store' : 'Play Store';

  @override
  void onInit() {
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        _subscription.cancel();
      },
    );
    super.onInit();
    initStoreInfo();
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }

  Future<void> initStoreInfo() async {
    isStoreReady.value = false;
    storeMessage.value = null;

    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      storeMessage.value = 'In-app purchases are unavailable on this device.';
      debugPrint('Store not available');
      return;
    }

    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails({monthlyId, yearlyId});

    debugPrint('NOT FOUND IDS: ${response.notFoundIDs}');
    debugPrint('FOUND: ${response.productDetails.length}');
    debugPrint('ERROR: ${response.error}');

    if (response.error != null) {
      storeMessage.value =
          'Unable to load subscription products from the $storeName.';
      debugPrint('Error loading products: ${response.error!.message}');
      return;
    }

    if (response.productDetails.isEmpty) {
      storeMessage.value =
          'No subscription products were returned by the $storeName.';
      debugPrint('No product details returned from the store.');
      return;
    }

    availableProducts.value = response.productDetails;
    isStoreReady.value = true;
  }

  void selectPlan(int plan) {
    if (isPurchasing.value) return; // Disable changing plan while purchasing
    selectedPlan.value = plan;
  }

  Future<void> purchaseSelectedPlan() async {
    if (selectedPlan.value == 0) return;
    if (isPurchasing.value) {
      debugPrint('⚠️ Purchase already in progress. Skipping request.');
      return;
    }
    if (!isStoreReady.value) {
      Get.snackbar(
        'Store Unavailable',
        storeMessage.value ?? 'Subscription products are still loading.',
      );
      return;
    }

    isPurchasing.value = true;
    String targetId = selectedPlan.value == 1 ? monthlyId : yearlyId;

    ProductDetails? productDetails;
    try {
      productDetails = availableProducts.firstWhere((p) => p.id == targetId);
    } catch (e) {
      productDetails = null;
    }

    if (productDetails == null) {
      isPurchasing.value = false;
      Get.snackbar(
        'Product Missing',
        'The selected subscription is not available from the $storeName.',
      );
      return;
    }

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: productDetails,
    );

    try {
      // Subscriptions use buyNonConsumable in most use cases for updating existing subscriptions or new ones
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      isPurchasing.value = false;
      Get.snackbar('Error', e.toString());
    }
  }

  Future<void> restorePurchases() async {
    try {
      isPurchasing.value = true;
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      isPurchasing.value = false;
      Get.snackbar('Error', 'Failed to restore purchases: $e');
    }
  }

  Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint(
        '📦 Purchase Update: ID=${purchaseDetails.purchaseID}, Status=${purchaseDetails.status}',
      );

      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Waiting for the purchase to complete
        isPurchasing.value = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('❌ Purchase Error: ${purchaseDetails.error?.message}');
          isPurchasing.value = false;
          Get.snackbar(
            'Purchase Failed',
            purchaseDetails.error?.message ?? 'Unknown error',
          );
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          debugPrint('🚫 Purchase Canceled by User');
          isPurchasing.value = false;
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          debugPrint('✅ Purchase Success/Restored: Processing backend sync...');
          await _handleSuccessfulPurchase(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          debugPrint('🏁 Completing Purchase Transaction...');
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    // 1. Keep loading state true while backend verification happens
    isPurchasing.value = true;

    try {
      final String transactionId = purchaseDetails.purchaseID ?? '';

      // 2. Validate transaction_id (Critical Rule)
      if (transactionId.isEmpty || transactionId == 'Unknown') {
        debugPrint('❌ Invalid Transaction ID: $transactionId');
        isPurchasing.value = false;
        return;
      }

      // 3. Prevent duplicate transactions (Critical Rule)
      final prefs = await SharedPreferences.getInstance();
      List<String> processedTransactions =
          prefs.getStringList('processed_transactions') ?? [];

      if (processedTransactions.contains(transactionId)) {
        debugPrint('⚠️ Transaction already processed: $transactionId');
        isPurchasing.value = false;
        // Purchase was already synced, so we can consider it successful locally
        await fetchSubscriptionStatus();
        return;
      }

      // 4. Convert Product ID (VERY IMPORTANT)
      String backendProductId = '';
      if (purchaseDetails.productID == monthlyId) {
        backendProductId = 'hattersprime_monthly';
      } else if (purchaseDetails.productID == yearlyId) {
        backendProductId = 'hattersprime_yearly';
      }

      if (backendProductId.isEmpty) {
        debugPrint('❌ Unsupported Product ID: ${purchaseDetails.productID}');
        isPurchasing.value = false;
        Get.snackbar('Error', 'Unsupported subscription product.');
        return;
      }

      // 5. Call API (Only after purchase success)
      final token = prefs.getString('wordpressAuthToken') ?? '';

      // Endpoint: {{website-link}}/wp-json/imc/v1/subscription/update
      final url = Uri.parse(
        '${AppConstants.webUrl}wp-json/imc/v1/subscription/update',
      );

      final requestBody = {
        'product_id': backendProductId,
        'transaction_id': transactionId,
        'source': 'app',
        'platform': Platform.isIOS ? 'ios' : 'android',
      };

      debugPrint('\n======= 🚀 SUBSCRIPTION UPDATE API CALL =======');
      debugPrint('URL: $url');
      debugPrint(
        'HEADER: Authorization: Bearer ${token.isNotEmpty ? "${token.substring(0, 5)}***" : "EMPTY"}',
      );
      debugPrint('BODY: ${jsonEncode(requestBody)}');
      debugPrint('===============================================\n');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 6. Mark transaction as processed upon success
        processedTransactions.add(transactionId);
        await prefs.setStringList(
          'processed_transactions',
          processedTransactions,
        );

        // Update local status
        await fetchSubscriptionStatus();

        Get.snackbar(
          'Success',
          'Subscription updated successfully!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        debugPrint('❌ Backend verification failed: ${response.body}');
        Get.snackbar(
          'Update Failed',
          'Could not sync subscription with server. Please try again.',
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating subscription: $e');
      Get.snackbar(
        'Error',
        'An unexpected error occurred during verification.',
      );
    } finally {
      isPurchasing.value = false;
    }
  }
}
