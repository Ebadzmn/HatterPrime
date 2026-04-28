class SubscriptionResponse {
  final String status;
  final String plan;
  final DateTime? expiresAt;
  final bool renewed;

  SubscriptionResponse({
    required this.status,
    required this.plan,
    this.expiresAt,
    required this.renewed,
  });

  factory SubscriptionResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionResponse(
      status: json['status'] ?? '',
      plan: json['plan'] ?? '',
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
      renewed: json['renewed'] ?? false,
    );
  }
}
