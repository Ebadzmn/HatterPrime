import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hatters_prime/constants.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

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

      final url = Uri.parse(
        '${AppConstants.webUrl}wp-json/imc/v1/subscription-status',
      );
      debugPrint('\n======= 🔄 FETCH SUBSCRIPTION STATUS =======');
      debugPrint('URL: $url');

      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE: ${response.body}');
      debugPrint('============================================\n');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        isSubscribed.value = data['status'] == 'active';
        subscriptionPlan.value = data['plan'] ?? '';
        subscriptionExpiry.value = data['expires_at'];
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
  final String _monthlyId = 'com.hattersgroup.monthly';
  final String _yearlyId = 'com.HattersCollectiveGroup.Yearly';

  var availableProducts = <ProductDetails>[].obs;

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
    _initStoreInfo();
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }

  Future<void> _initStoreInfo() async {
    isStoreReady.value = false;
    storeMessage.value = null;

    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      storeMessage.value = 'In-app purchases are unavailable on this device.';
      debugPrint('Store not available');
      return;
    }

    final ProductDetailsResponse response = await _inAppPurchase
        .queryProductDetails({_monthlyId, _yearlyId});

    debugPrint('NOT FOUND IDS: ${response.notFoundIDs}');
    debugPrint('FOUND: ${response.productDetails.length}');
    debugPrint('ERROR: ${response.error}');

    if (response.error != null) {
      storeMessage.value =
          'Unable to load subscription products from the App Store.';
      debugPrint('Error loading products: ${response.error!.message}');
      return;
    }

    if (response.productDetails.isEmpty) {
      storeMessage.value =
          'No subscription products were returned by the App Store.';
      debugPrint('No product details returned by StoreKit.');
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
    if (!isStoreReady.value) {
      Get.snackbar(
        'Store Unavailable',
        storeMessage.value ?? 'Subscription products are still loading.',
      );
      return;
    }

    isPurchasing.value = true;
    String targetId = selectedPlan.value == 1 ? _monthlyId : _yearlyId;

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
        'The selected subscription is not available from the App Store.',
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
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Waiting for the purchase to complete
        isPurchasing.value = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          isPurchasing.value = false;
          Get.snackbar(
            'Purchase Failed',
            purchaseDetails.error?.message ?? 'Unknown error',
          );
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          isPurchasing.value = false;
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          await _handleSuccessfulPurchase(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    // Keep loading state true while backend verification happens
    isPurchasing.value = true;

    // Mapping details as per requirement
    const String platform =
        'ios'; // You can also check Platform.isIOS dynamically
    String backendProductId = '';

    // Purchase Date formatting
    DateTime purchaseDate = DateTime.now();
    DateTime expiryDate = purchaseDate;

    if (purchaseDetails.productID == _monthlyId) {
      backendProductId = 'hattersprime_monthly';
      // +1 month
      expiryDate = DateTime(
        purchaseDate.year,
        purchaseDate.month + 1,
        purchaseDate.day,
      );
    } else if (purchaseDetails.productID == _yearlyId) {
      backendProductId = 'hattersprime_yearly';
      // +1 year
      expiryDate = DateTime(
        purchaseDate.year + 1,
        purchaseDate.month,
        purchaseDate.day,
      );
    }

    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String purchaseDateStr = formatter.format(purchaseDate);
    final String expiryDateStr = formatter.format(expiryDate);
    final String transactionId = purchaseDetails.purchaseID ?? 'Unknown';

    if (backendProductId.isEmpty) {
      isPurchasing.value = false;
      Get.snackbar(
        'Purchase Error',
        'The purchased product does not match a supported subscription.',
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('wordpressAuthToken') ?? '';

      // Update this URL to match your exact backend endpoint
      final url = Uri.parse(
        '${AppConstants.webUrl}wp-json/custom/v1/subscription/update',
      );

      final requestBody = {
        'platform': platform,
        'product_id': backendProductId,
        'transaction_id': transactionId,
        'purchase_date': purchaseDateStr,
        'expiry_date': expiryDateStr,
      };

      debugPrint('\n======= 🚀 API CALL START =======');
      debugPrint('URL: $url');
      debugPrint(
        'HEADERS: {Content-Type: application/json, Authorization: Bearer ${token.isNotEmpty ? "TOKEN_EXISTS" : "NO_TOKEN"}}',
      );
      debugPrint('BODY: ${jsonEncode(requestBody)}');
      debugPrint('===================================\n');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint('\n======= 📥 API CALL RESPONSE =======');
      debugPrint('STATUS CODE: ${response.statusCode}');
      debugPrint('RESPONSE BODY: ${response.body}');
      debugPrint('======================================\n');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Get.snackbar(
          'Success',
          'Your subscription is now active!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF005E41),
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
        );
      } else {
        Get.snackbar(
          'Verification Failed',
          'Status: ${response.statusCode}. Could not verify subscription with server.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      debugPrint('\n======= ❌ API CALL ERROR =======');
      debugPrint('ERROR: $e');
      debugPrint('===================================\n');
      Get.snackbar(
        'Error',
        'Network error during subscription verification.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isPurchasing.value = false;
    }
  }
}
