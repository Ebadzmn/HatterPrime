import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/purchase_details.dart';
import '../models/subscription_response.dart';
import 'dart:io';

class SubscriptionService {
  static const String baseUrl = 'https://your-api.com/api';

  // Mocking the AuthService.getToken()
  Future<String> _getJwtToken() async {
    // Replace with your actual auth service logic
    return 'your_jwt_token_here';
  }

  Future<SubscriptionResponse> verifyPurchase(PurchaseDetails purchase) async {
    final token = await _getJwtToken();
    final url = Uri.parse('$baseUrl/subscription/update');

    final platform = Platform.isIOS ? 'ios' : 'android';

    final body = {
      'platform': platform,
      'product_id': purchase.productId,
      'transaction_id': purchase.transactionId,
      'purchase_date': purchase.purchaseDate,
      'expiry_date': purchase.expiryDate,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      return SubscriptionResponse.fromJson(jsonResponse);
    } else {
      throw Exception('Failed to verify subscription. Status: ${response.statusCode}');
    }
  }
}
