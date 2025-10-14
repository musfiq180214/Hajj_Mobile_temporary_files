import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labbayk/core/network/api_client.dart';
import 'package:labbayk/core/utils/logger.dart';
import 'package:labbayk/features/refund/domain/refund_model.dart';

final refundControllerProvider =
    ChangeNotifierProvider<RefundController>((ref) {
  return RefundController(ref);
});

class RefundController extends ChangeNotifier {
  final Ref ref;
  late final ApiClient apiClient = ref.read(apiClientProvider);

  RefundController(this.ref);
  final RefundModel model = RefundModel();

  final Set<String> selectedTrackingNos = {};
  String? initialTrackingNo;

  List<Map<String, dynamic>> hajjAgencies = [];
  Map<String, dynamic>? selectedAgency;

  List<Map<String, dynamic>> bankList = [];
  List<Map<String, dynamic>> districtList = [];
  List<Map<String, dynamic>> branchList = [];

  Map<String, dynamic>? selectedBankItem;
  Map<String, dynamic>? selectedDistrictItem;
  Map<String, dynamic>? selectedBranchItem;

  // ---------------- Fetch Refund List ----------------
  Future<List<Map<String, dynamic>>> fetchRefundList() async {
    try {
      final res = await apiClient.dio.get('/v2/user/refunds');
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      AppLogger.e("Fetch refund list error: $e");
      return [];
    }
  }

  // ---------------- Fetch Refund Detail ----------------
  Future<Map<String, dynamic>?> fetchRefundDetail(int refundId) async {
    try {
      final res = await apiClient.dio.get('/v2/user/refunds/$refundId');
      if (res.statusCode == 200 && res.data is Map) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (e) {
      AppLogger.e("Fetch refund detail error: $e");
      return null;
    }
  }

  // ---------------- Send OTP ----------------
  Future<void> sendOtp(String trackingNo, String phone, String forWhat) async {
    if (forWhat != "pre_registration" && forWhat != "registration") {
      throw ArgumentError(
          "Invalid 'for' parameter: '$forWhat'. Must be 'pre_registration' or 'registration'.");
    }

    final body = {'tracking_no': trackingNo, 'phone': phone, 'for': forWhat};

    try {
      final res =
          await apiClient.dio.post('/v2/user/refunds/get_otp', data: body);
      if (res.statusCode == 200 && res.data['request_key'] != null) {
        setRequestKey(res.data['request_key']);
        setOtpSent(true);
      } else {
        throw Exception(res.data['error'] ?? 'OTP request failed');
      }
    } catch (e) {
      AppLogger.e("Send OTP error: $e");
      rethrow;
    }
  }

  // ---------------- Verify OTP ----------------
  Future<bool> verifyOtp(String otp) async {
    final body = {'request_key': model.requestKey, 'otp': otp};

    try {
      final res =
          await apiClient.dio.post('/v2/user/refunds/verify_otp', data: body);
      if (res.statusCode == 200 &&
          res.data != null &&
          res.data['pilgrim_info'] != null) {
        model.pilgrimData = Map<String, dynamic>.from(res.data['pilgrim_info']);
        model.groupPaymentReference = int.tryParse(
            res.data['pilgrim_info']['group_payment_id']?.toString() ?? '');
        model.groupPilgrims = List<Map<String, dynamic>>.from(
            res.data['group_pilgrim_list'] ?? []);
        setOtpVerified(true);
        return true;
      } else {
        throw Exception(res.data['error'] ?? 'OTP verification failed');
      }
    } catch (e) {
      AppLogger.e("Verify OTP error: $e");
      setOtpVerified(false);
      return false;
    }
  }

  // ---------------- Submit Refund ----------------
  Future<bool> submitRefund({
    Map<String, dynamic>? paymentData,
    int? agencyId,
  }) async {
    if (model.requestKey.isEmpty || selectedTrackingNos.isEmpty) return false;
    if (model.selectedMethod == null) {
      AppLogger.e("⛔ Payment method not selected");
      return false;
    }

    final Map<String, dynamic> body = {
      'request_key': model.requestKey,
      'tracking_nos[]': selectedTrackingNos.toList(),
      'agency_id': agencyId,
      'payment_type': model.selectedMethod!,
      if (paymentData != null) ...paymentData,
    };

    try {
      final res = await apiClient.dio.post(
        '/v2/user/refunds/submit',
        data: FormData.fromMap(body),
      );
      if (res.statusCode == 200) return true;
      throw Exception(res.data['error'] ?? 'Refund submission failed');
    } catch (e) {
      AppLogger.e("Submit refund error: $e");
      return false;
    }
  }

  // ---------------- Dropdown APIs ----------------
  Future<void> loadHajjAgencies({String? keywords}) async {
    try {
      final res = await apiClient.dio.get(
        '/v2/user/dropdown/agencies',
        queryParameters: keywords != null ? {'keywords': keywords} : null,
      );
      if (res.statusCode == 200 && res.data is List) {
        hajjAgencies = List<Map<String, dynamic>>.from(res.data);
      }
    } catch (e) {
      AppLogger.e("Fetch Hajj Agencies error: $e");
      hajjAgencies = [];
    }
    notifyListeners();
  }

  Future<void> loadBanks({String? keywords}) async {
    try {
      final res = await apiClient.dio.get(
        '/v2/user/dropdown/banks',
        queryParameters: keywords != null ? {'keywords': keywords} : null,
      );
      if (res.statusCode == 200 && res.data is List) {
        bankList = List<Map<String, dynamic>>.from(res.data);
      }
    } catch (e) {
      AppLogger.e("Fetch Banks error: $e");
      bankList = [];
    }
    notifyListeners();
  }

  Future<void> loadDistricts({String? keywords}) async {
    if (selectedBankItem == null) return;
    try {
      final res = await apiClient.dio.get(
        '/v2/user/dropdown/bank_districts',
        queryParameters: {
          'bank_id': selectedBankItem!['id'],
          if (keywords != null) 'keywords': keywords,
        },
      );
      if (res.statusCode == 200 && res.data is List) {
        districtList = List<Map<String, dynamic>>.from(res.data);
      }
    } catch (e) {
      AppLogger.e("Fetch Bank Districts error: $e");
      districtList = [];
    }
    notifyListeners();
  }

  Future<void> loadBranches({String? keywords}) async {
    if (selectedBankItem == null || selectedDistrictItem == null) return;
    try {
      final res = await apiClient.dio.get(
        '/v2/user/dropdown/bank_branches',
        queryParameters: {
          'bank_id': selectedBankItem!['id'],
          'district_id': selectedDistrictItem!['id'],
          if (keywords != null) 'keywords': keywords,
        },
      );
      if (res.statusCode == 200 && res.data is List) {
        branchList = List<Map<String, dynamic>>.from(res.data);
      }
    } catch (e) {
      AppLogger.e("Fetch Bank Branches error: $e");
      branchList = [];
    }
    notifyListeners();
  }

  // ---------------- Setters ----------------
  Future<void> setSelectedBank(Map<String, dynamic>? bank) async {
    if (selectedBankItem == bank) return;
    selectedBankItem = bank;
    selectedDistrictItem = null;
    selectedBranchItem = null;
    districtList = [];
    branchList = [];
    notifyListeners();
    if (bank != null) await loadDistricts();
  }

  Future<void> setSelectedDistrict(Map<String, dynamic>? district) async {
    if (selectedDistrictItem == district) return;
    selectedDistrictItem = district;
    selectedBranchItem = null;
    branchList = [];
    notifyListeners();
    if (district != null) await loadBranches();
  }

  void setSelectedBranch(Map<String, dynamic>? branch) {
    selectedBranchItem = branch;
    notifyListeners();
  }

  void setSelectedMethod(String? method) {
    model.selectedMethod = method;
    notifyListeners();
  }

  void setOtpSent(bool value) {
    model.otpSent = value;
    notifyListeners();
  }

  void setOtpVerified(bool value) {
    model.otpVerified = value;
    notifyListeners();
  }

  void setRequestKey(String key) {
    model.requestKey = key;
    notifyListeners();
  }

  void togglePilgrimSelection(String trackingNo, bool isSelected) {
    if (trackingNo == initialTrackingNo) return;
    if (isSelected) {
      selectedTrackingNos.add(trackingNo);
    } else {
      selectedTrackingNos.remove(trackingNo);
    }
    notifyListeners();
  }

  bool isPilgrimSelected(String trackingNo) =>
      selectedTrackingNos.contains(trackingNo);

  void setSelectedAgency(Map<String, dynamic>? agency) {
    selectedAgency = agency;
    notifyListeners();
  }

  // ---------------- Reset ----------------
  void reset() {
    model
      ..otpSent = false
      ..otpVerified = false
      ..requestKey = ""
      ..selectedMethod = null
      ..groupPaymentReference = null
      ..pilgrimData = null
      ..groupPilgrims.clear();

    selectedTrackingNos.clear();
    selectedBankItem = null;
    selectedDistrictItem = null;
    selectedBranchItem = null;
    notifyListeners();
  }
}
