import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

class MembershipController extends GetxController {
  // 1 for basic (monthly), 2 for premium (yearly)
  var selectedPlan = 2.obs;
  var isPurchasing = false.obs;

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // Product IDs matching the requirement
  final String _monthlyId = 'com.HattersCollectiveGroup.Monthly';
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
    _initStoreInfo();
    super.onInit();
  }

  @override
  void onClose() {
    _subscription.cancel();
    super.onClose();
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      debugPrint('Store not available');
      return;
    }

    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({_monthlyId, _yearlyId});

    print("NOT FOUND IDS: ${response.notFoundIDs}");
    print("FOUND: ${response.productDetails.length}");
    print("ERROR: ${response.error}");

    if (response.error != null) {
      debugPrint('Error loading products: ${response.error!.message}');
      return;
    }
    availableProducts.value = response.productDetails;
  }

  void selectPlan(int plan) {
    if (isPurchasing.value) return; // Disable changing plan while purchasing
    selectedPlan.value = plan;
  }

  Future<void> purchaseSelectedPlan() async {
    if (selectedPlan.value == 0) return;
    
    isPurchasing.value = true;
    String targetId = selectedPlan.value == 1 ? _monthlyId : _yearlyId;
    
    ProductDetails? productDetails;
    try {
      productDetails = availableProducts.firstWhere((p) => p.id == targetId);
    } catch (e) {
      // Ignore if not found, we will create a dummy ProductDetails object if necessary
    }

    final PurchaseParam purchaseParam = productDetails != null 
        ? PurchaseParam(productDetails: productDetails)
        : PurchaseParam(productDetails: ProductDetails(id: targetId, title: '', description: '', price: '', rawPrice: 0, currencyCode: ''));

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

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Waiting for the purchase to complete
        isPurchasing.value = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          isPurchasing.value = false;
          Get.snackbar('Purchase Failed', purchaseDetails.error?.message ?? 'Unknown error');
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          isPurchasing.value = false;
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          await _handleSuccessfulPurchase(purchaseDetails);
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) async {
    isPurchasing.value = false;

    // Mapping details as per requirement
    const String platform = 'ios';
    String backendProductId = '';
    
    // Purchase Date formatting
    DateTime purchaseDate = DateTime.now();
    DateTime expiryDate = purchaseDate;

    if (purchaseDetails.productID == _monthlyId) {
      backendProductId = 'hattersprime_monthly';
      // +1 month
      expiryDate = DateTime(purchaseDate.year, purchaseDate.month + 1, purchaseDate.day);
    } else if (purchaseDetails.productID == _yearlyId) {
      backendProductId = 'hattersprime_yearly';
      // +1 year
      expiryDate = DateTime(purchaseDate.year + 1, purchaseDate.month, purchaseDate.day);
    }

    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String purchaseDateStr = formatter.format(purchaseDate);
    final String expiryDateStr = formatter.format(expiryDate);
    final String transactionId = purchaseDetails.purchaseID ?? 'Unknown';

    // Print to debug console
    debugPrint('======= IAP SUCCESS =======');
    debugPrint('platform: $platform');
    debugPrint('product_id: $backendProductId');
    debugPrint('transaction_id: $transactionId');
    debugPrint('purchase_date: $purchaseDateStr');
    debugPrint('expiry_date: $expiryDateStr');
    debugPrint('===========================');

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
  }
}
