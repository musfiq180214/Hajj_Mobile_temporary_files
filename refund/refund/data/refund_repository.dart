import 'package:dio/dio.dart';
import 'package:labbayk/core/network/api_client.dart';

abstract class IRefundRepository {
  Future<List<Map<String, dynamic>>> fetchRefundList();
  Future<Map<String, dynamic>?> fetchRefundDetail(int refundId);
  Future<String> sendOtp(String trackingNo, String phone, String forWhat);
  Future<Map<String, dynamic>> verifyOtp(String requestKey, String otp);
  Future<bool> submitRefund(Map<String, dynamic> body);
  Future<List<Map<String, dynamic>>> fetchDropdown(String endpoint,
      {Map<String, dynamic>? params});
}

class RefundRepository implements IRefundRepository {
  final ApiClient apiClient;

  RefundRepository(this.apiClient);

  Dio get _dio => apiClient.dio;

  @override
  Future<List<Map<String, dynamic>>> fetchRefundList() async {
    final res = await _dio.get('/v2/user/refunds');
    if (res.statusCode == 200 && res.data is List) {
      return List<Map<String, dynamic>>.from(res.data);
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>?> fetchRefundDetail(int refundId) async {
    final res = await _dio.get('/v2/user/refunds/$refundId');
    if (res.statusCode == 200 && res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    }
    return null;
  }

  @override
  Future<String> sendOtp(
      String trackingNo, String phone, String forWhat) async {
    final body = {'tracking_no': trackingNo, 'phone': phone, 'for': forWhat};
    final res = await _dio.post('/v2/user/refunds/get_otp', data: body);

    if (res.statusCode == 200 && res.data != null) {
      final requestKey = res.data['request_key'] as String?;
      if (requestKey != null && requestKey.isNotEmpty) {
        return requestKey;
      }
    }

    final error =
        (res.data is Map) ? (res.data['error'] ?? res.data['message']) : null;
    throw Exception(error?.toString() ?? 'OTP request failed');
  }

  @override
  Future<Map<String, dynamic>> verifyOtp(String requestKey, String otp) async {
    final body = {'request_key': requestKey, 'otp': otp};
    final res = await _dio.post('/v2/user/refunds/verify_otp', data: body);

    if (res.statusCode == 200 && res.data is Map) {
      return Map<String, dynamic>.from(res.data);
    }

    final error =
        (res.data is Map) ? (res.data['error'] ?? res.data['message']) : null;
    throw Exception(error?.toString() ?? 'OTP verification failed');
  }

  @override
  Future<bool> submitRefund(Map<String, dynamic> body) async {
    final res = await _dio.post('/v2/user/refunds/submit',
        data: FormData.fromMap(body));
    return res.statusCode == 200;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDropdown(String endpoint,
      {Map<String, dynamic>? params}) async {
    final res =
        await _dio.get('/v2/user/dropdown/$endpoint', queryParameters: params);
    if (res.statusCode == 200 && res.data is List) {
      return List<Map<String, dynamic>>.from(res.data);
    }
    return [];
  }
}
