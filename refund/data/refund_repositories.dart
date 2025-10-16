import 'package:dio/dio.dart';
import 'package:labbayk/core/network/api_client.dart';

class RefundRepository {
  final ApiClient apiClient;

  RefundRepository(this.apiClient);

  Future<List<Map<String, dynamic>>> fetchRefundList() async {
    final res = await apiClient.dio.get('/v2/user/refunds');
    if (res.statusCode == 200 && res.data is List) {
      return List<Map<String, dynamic>>.from(res.data);
    }
    return [];
  }

  Future<Map<String, dynamic>?> fetchRefundDetail(int refundId) async {
    final res = await apiClient.dio.get('/v2/user/refunds/$refundId');
    if (res.statusCode == 200 && res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    }
    return null;
  }

  Future<String> sendOtp(
      String trackingNo, String phone, String forWhat) async {
    final body = {'tracking_no': trackingNo, 'phone': phone, 'for': forWhat};
    final res =
        await apiClient.dio.post('/v2/user/refunds/get_otp', data: body);

    if (res.statusCode == 200 && res.data['request_key'] != null) {
      return res.data['request_key'];
    }

    throw Exception(res.data['error'] ?? 'OTP request failed');
  }

  Future<Map<String, dynamic>> verifyOtp(String requestKey, String otp) async {
    final body = {'request_key': requestKey, 'otp': otp};
    final res =
        await apiClient.dio.post('/v2/user/refunds/verify_otp', data: body);

    if (res.statusCode == 200 && res.data['pilgrim_info'] != null) {
      return Map<String, dynamic>.from(res.data);
    }

    throw Exception(res.data['error'] ?? 'OTP verification failed');
  }

  Future<bool> submitRefund(Map<String, dynamic> body) async {
    final res = await apiClient.dio.post(
      '/v2/user/refunds/submit',
      data: FormData.fromMap(body),
    );

    return res.statusCode == 200;
  }

  Future<List<Map<String, dynamic>>> fetchDropdown(
    String endpoint, {
    Map<String, dynamic>? params,
  }) async {
    final res = await apiClient.dio.get(
      '/v2/user/dropdown/$endpoint',
      queryParameters: params,
    );

    if (res.statusCode == 200 && res.data is List) {
      return List<Map<String, dynamic>>.from(res.data);
    }

    return [];
  }
}
