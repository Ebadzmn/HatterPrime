class PurchaseDetails {
  final String productId;
  final String transactionId;
  final String? purchaseDate;
  final String? expiryDate;

  PurchaseDetails({
    required this.productId,
    required this.transactionId,
    this.purchaseDate,
    this.expiryDate,
  });
}
