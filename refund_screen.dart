import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labbayk/features/auth/providers/login_provider.dart';

// ----------------- Logger -----------------
class AppLoggerRefund {
  static void i(String message) => debugPrint("💡 $message");
  static void e(String message) => debugPrint("⛔ $message");
}

// ----------------- Refund Model -----------------
class RefundModel {
  String? selectedMethod;
  bool otpSent = false;
  bool otpVerified = false;
  String requestKey = "";
  Map<String, dynamic>? pilgrimData;
  int? groupPaymentReference;
  List<Map<String, dynamic>> groupPilgrims = [];
}

class RefundApiClient {
  final Dio dio = Dio(BaseOptions(
    baseUrl: 'https://labbaik-api.innofast.tech',
    headers: {'Content-Type': 'application/json'},
  ));

  Future<List<dynamic>> fetchRefundList(Ref ref) async {
    final token = ref.read(authTokenProvider);
    final url = '/v2/user/refunds';
    try {
      AppLoggerRefund.i("⏳ [API REQUEST] GET $url");
      final res = await dio.get(url,
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      AppLoggerRefund.i(
          "✅ [API RESPONSE] ${res.statusCode} $url\nData: ${res.data}");
      return res.data ?? [];
    } catch (e) {
      AppLoggerRefund.e("Fetch refund list error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchRefundDetail(Ref ref, int refundId) async {
    final token = ref.read(authTokenProvider);
    final url = '/v2/user/refunds/$refundId';
    try {
      AppLoggerRefund.i("⏳ [API REQUEST] GET $url");
      final res = await dio.get(url,
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      AppLoggerRefund.i(
          "✅ [API RESPONSE] ${res.statusCode} $url\nData: ${res.data}");
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (e) {
      AppLoggerRefund.e("Fetch refund detail error: $e");
      return null;
    }
  }

  Future<String> sendOtp(
      Ref ref, String trackingNo, String phone, String forWhat) async {
    final token = ref.read(authTokenProvider);
    final url = '/v2/user/refunds/get_otp';

    if (forWhat != "pre_registration" && forWhat != "registration") {
      final errorMsg =
          "Invalid 'for' parameter: '$forWhat'. Must be 'pre_registration' or 'registration'.";
      AppLoggerRefund.e(errorMsg);
      throw ArgumentError(errorMsg);
    }

    final body = {'tracking_no': trackingNo, 'phone': phone, 'for': forWhat};

    try {
      AppLoggerRefund.i(
          "⏳ [API REQUEST] POST $url\nHeaders: Authorization: Bearer $token\nData: $body");
      final res = await dio.post(
        url,
        data: jsonEncode(body),
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      AppLoggerRefund.i(
          "💡 [API RESPONSE] ${res.statusCode} $url\nData: ${res.data}");
      if (res.statusCode == 200) {
        final requestKey = res.data['request_key'];
        if (requestKey == null) {
          throw Exception("API did not return request_key");
        }
        return requestKey;
      } else if (res.statusCode == 422 || res.statusCode == 400) {
        throw Exception(res.data['error'] ?? 'Validation or bad request');
      } else {
        throw Exception('Unexpected error ${res.statusCode}: ${res.data}');
      }
    } catch (e) {
      AppLoggerRefund.e("⛔ Send OTP error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> verifyOtp(
      Ref ref, String requestKey, String otp) async {
    final token = ref.read(authTokenProvider);
    final url = '/v2/user/refunds/verify_otp';
    final body = {'request_key': requestKey, 'otp': otp};

    try {
      AppLoggerRefund.i("⏳ [API REQUEST] POST $url\nData: $body");
      final res = await dio.post(
        url,
        data: jsonEncode(body),
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      AppLoggerRefund.i(
          "💡 [API RESPONSE] ${res.statusCode} $url\nData: ${res.data}");
      if (res.statusCode == 200 &&
          res.data != null &&
          res.data['pilgrim_info'] != null) {
        return Map<String, dynamic>.from(res.data);
      } else if (res.statusCode == 422) {
        throw Exception(res.data['error'] ?? 'Validation error');
      } else if (res.statusCode == 404) {
        throw Exception(
            'OTP verification failed: request_key not found or expired');
      } else {
        throw Exception('Unexpected error ${res.statusCode}: ${res.data}');
      }
    } catch (e) {
      AppLoggerRefund.e("⛔ Verify OTP error: $e");
      rethrow;
    }
  }

  Future<bool> submitRefundWithDirectFields(
      Ref ref, Map<String, dynamic> body) async {
    final token = ref.read(authTokenProvider);
    final url = '/v2/user/refunds/submit';

    try {
      AppLoggerRefund.i(
          "⏳ [API REQUEST] POST $url\nData: $body, 'Authorization': 'Bearer $token',");
      final res = await dio.post(
        url,
        // data: jsonEncode(body),
        data: FormData.fromMap(body),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/form-data'
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      AppLoggerRefund.i(
          "💡 [API RESPONSE] ${res.statusCode} $url\nData: ${res.data}");
      if (res.statusCode == 200) return true;
      final error = res.data['error'] ?? 'Validation or bad request';
      throw Exception(error);
    } catch (e) {
      AppLoggerRefund.e("⛔ Submit refund error: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchHajjAgencies(Ref ref,
      {String? keywords}) async {
    final token = ref.read(authTokenProvider);
    final url = '/v2/user/dropdown/agencies';
    try {
      final res = await dio.get(
        url,
        queryParameters: keywords != null ? {'keywords': keywords} : null,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      AppLoggerRefund.i("Fetch Hajj Agencies response:");
      AppLoggerRefund.i(res.toString());
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      AppLoggerRefund.e("Fetch Hajj Agencies error: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchBanks(Ref ref,
      {String? keywords}) async {
    final token = ref.read(authTokenProvider);
    const url = '/v2/user/dropdown/banks';
    try {
      final res = await dio.get(
        url,
        queryParameters: keywords != null ? {'keywords': keywords} : null,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      AppLoggerRefund.i("Fetch Bank response:");
      AppLoggerRefund.i(res.toString());
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      AppLoggerRefund.e("Fetch Banks error: $e");
      return [];
    }
  }

  // ----------------- Fetch Bank Districts -----------------
  Future<List<Map<String, dynamic>>> fetchBankDistricts(
    Ref ref, {
    required int bankId,
    String? keywords,
  }) async {
    final token = ref.read(authTokenProvider);
    const url = '/v2/user/dropdown/bank_districts';

    try {
      final res = await dio.get(
        url,
        queryParameters: {
          'bank_id': bankId,
          if (keywords != null) 'keywords': keywords,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }

      return [];
    } catch (e) {
      AppLoggerRefund.e("Fetch Bank Districts error: $e");
      return [];
    }
  }

// ----------------- Fetch Bank Branches -----------------
  Future<List<Map<String, dynamic>>> fetchBankBranches(
    Ref ref, {
    required int bankId,
    required int districtId,
    String? keywords,
  }) async {
    final token = ref.read(authTokenProvider);
    const url = '/v2/user/dropdown/bank_branches';

    try {
      final res = await dio.get(
        url,
        queryParameters: {
          'bank_id': bankId,
          'district_id': districtId,
          if (keywords != null) 'keywords': keywords,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }

      return [];
    } catch (e) {
      AppLoggerRefund.e("Fetch Bank Branches error: $e");
      return [];
    }
  }
}

// ----------------- Refund Controller -----------------
final refundControllerProvider =
    ChangeNotifierProvider<RefundController>((ref) {
  return RefundController(ref);
});

class RefundController extends ChangeNotifier {
  final Ref ref;
  RefundController(this.ref);

  final RefundApiClient apiClient = RefundApiClient();
  final RefundModel model = RefundModel();
  final Set<String> selectedTrackingNos = {};
  String? initialTrackingNo;

  List<Map<String, dynamic>> hajjAgencies = [];
  Map<String, dynamic>? selectedAgency;

  // ----------------- Bank Dropdown States -----------------
  List<Map<String, dynamic>> bankList = [];
  List<Map<String, dynamic>> districtList = [];
  List<Map<String, dynamic>> branchList = [];

  Map<String, dynamic>? selectedBankItem;
  Map<String, dynamic>? selectedDistrictItem;
  Map<String, dynamic>? selectedBranchItem;

  // ----------------- Load Banks -----------------
  Future<void> loadBanks({String? keywords}) async {
    final newBankList = await apiClient.fetchBanks(ref, keywords: keywords);
    bankList = newBankList;

    // Keep previous selection if still exists
    if (selectedBankItem != null) {
      final exists = bankList.firstWhere(
        (b) => b['id'] == selectedBankItem!['id'],
        orElse: () => {},
      );
      if (exists.isEmpty) {
        selectedBankItem = null;
        selectedDistrictItem = null;
        selectedBranchItem = null;
        districtList = [];
        branchList = [];
      }
    }

    notifyListeners();
  }

  Future<void> loadHajjAgencies({String? keywords}) async {
    final newHajjAgencies =
        await apiClient.fetchHajjAgencies(ref, keywords: keywords);
    hajjAgencies = newHajjAgencies;

    // Keep previous selection if still exists
    if (selectedBankItem != null) {
      final exists = bankList.firstWhere(
        (b) => b['id'] == selectedBankItem!['id'],
        orElse: () => {},
      );
      if (exists.isEmpty) {
        selectedBankItem = null;
        selectedDistrictItem = null;
        selectedBranchItem = null;
        districtList = [];
        branchList = [];
      }
    }

    notifyListeners();
  }

// ----------------- Load Districts -----------------
  Future<void> loadDistricts({String? keywords}) async {
    if (selectedBankItem == null) return;
    final newDistrictList = await apiClient.fetchBankDistricts(
      ref,
      bankId: selectedBankItem!['id'],
      keywords: keywords,
    );
    districtList = newDistrictList;

    // Keep previous selection if still exists
    if (selectedDistrictItem != null) {
      final exists = districtList.firstWhere(
        (d) => d['id'] == selectedDistrictItem!['id'],
        orElse: () => {},
      );
      if (exists.isEmpty) {
        selectedDistrictItem = null;
        selectedBranchItem = null;
        branchList = [];
      }
    }

    notifyListeners();
  }

// ----------------- Load Branches -----------------
  Future<void> loadBranches({String? keywords}) async {
    if (selectedBankItem == null || selectedDistrictItem == null) return;
    final newBranchList = await apiClient.fetchBankBranches(
      ref,
      bankId: selectedBankItem!['id'],
      districtId: selectedDistrictItem!['id'],
      keywords: keywords,
    );
    branchList = newBranchList;

    // Keep previous selection if still exists
    if (selectedBranchItem != null) {
      final exists = branchList.firstWhere(
        (b) => b['id'] == selectedBranchItem!['id'],
        orElse: () => {},
      );
      if (exists.isEmpty) selectedBranchItem = null;
    }

    notifyListeners();
  }

// ----------------- Setters -----------------
  Future<void> setSelectedBank(Map<String, dynamic>? bank) async {
    if (selectedBankItem == bank) return; // only update if different
    selectedBankItem = bank;

    // Reset dependent dropdowns only if bank changed
    selectedDistrictItem = null;
    selectedBranchItem = null;
    districtList = [];
    branchList = [];
    notifyListeners();

    if (bank != null) {
      await loadDistricts();
    }
  }

  Future<void> setSelectedDistrict(Map<String, dynamic>? district) async {
    if (selectedDistrictItem == district) return; // only update if different
    selectedDistrictItem = district;

    // Reset dependent dropdowns only if district changed
    selectedBranchItem = null;
    branchList = [];
    notifyListeners();

    if (district != null) {
      await loadBranches();
    }
  }

  void setSelectedBranch(Map<String, dynamic>? branch) {
    selectedBranchItem = branch;
    notifyListeners();
  }

  // ----------------- Setters -----------------
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
    // ✅ Prevent unselecting the initially entered tracking number
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

  // Future<void> loadHajjAgencies() async {
  //   hajjAgencies = await apiClient.fetchHajjAgencies(ref);
  //   notifyListeners();
  // }

  // Inside RefundController

  // Future<void> loadAgencies({String? keywords}) async {
  //   try {
  //     // Fetch the response from the API
  //     final response =
  //         await apiClient.fetchHajjAgencies(ref, keywords: keywords);

  //     // Log the exact response
  //     AppLogger.i("💡 Hajj Agencies Response: ${response.toString()}");

  //     // Assign it to your variable
  //     hajjAgencies = response;

  //     // Notify listeners to update UI
  //     notifyListeners();
  //   } catch (e, stackTrace) {
  //     AppLogger.i("⛔ Failed to load Hajj Agencies: $e");
  //     AppLogger.i(stackTrace.toString());
  //   }
  // }

  // ----------------- Fetch Refunds -----------------
  Future<List<Map<String, dynamic>>> fetchRefundList() async {
    try {
      final list = await apiClient.fetchRefundList(ref);
      return (list ?? [])
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      AppLoggerRefund.e("Controller fetchRefundList error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchRefundDetail(int refundId) async {
    try {
      return await apiClient.fetchRefundDetail(ref, refundId);
    } catch (e) {
      AppLoggerRefund.e("Controller fetchRefundDetail error: $e");
      return null;
    }
  }

  // ----------------- OTP -----------------
  Future<void> sendOtp(String trackingNo, String phone, String forWhat) async {
    final requestKey = await apiClient.sendOtp(ref, trackingNo, phone, forWhat);
    setRequestKey(requestKey);
    setOtpSent(true);
  }

  Future<bool> verifyOtp(String otp) async {
    final data = await apiClient.verifyOtp(ref, model.requestKey, otp);

    if (data != null && data['pilgrim_info'] != null) {
      model.pilgrimData = Map<String, dynamic>.from(data['pilgrim_info']);
      model.groupPaymentReference = int.tryParse(
          data['pilgrim_info']['group_payment_id']?.toString() ?? '');
      model.groupPilgrims =
          List<Map<String, dynamic>>.from(data['group_pilgrim_list'] ?? []);
      setOtpVerified(true);
      return true;
    }

    setOtpVerified(false);
    return false;
  }

  Future<bool> submitRefund(
      {Map<String, dynamic>? paymentData, int? agencyId}) async {
    if (model.requestKey.isEmpty || selectedTrackingNos.isEmpty) return false;

    if (model.selectedMethod == null) {
      AppLoggerRefund.e("⛔ Payment method is not selected");
      return false;
    }

    // Add agency_id if Hajj Agency or any explicit agency

    // ---------------- Prepare request body ----------------
    final Map<String, dynamic> requestBody = {
      'request_key': model.requestKey,
      'tracking_nos[]': "N17FE71E20", //["N17FE71E20", "N17FE5977A"],
      //'tracking_nos': selectedTrackingNos.toList(growable: false),
      'agency_id': agencyId,
      'payment_type': model.selectedMethod!,
    };

    // Merge paymentData directly into requestBody (flattened)
    if (paymentData != null && paymentData.isNotEmpty) {
      requestBody.addAll(paymentData);
    }

    // ---------------- Call API ----------------
    try {
      final success =
          await apiClient.submitRefundWithDirectFields(ref, requestBody);
      return success;
    } catch (e) {
      AppLoggerRefund.e("⛔ Submit refund error: $e");
      return false;
    }
  }

  // ----------------- Reset -----------------
  void reset() {
    model.otpSent = false;
    model.otpVerified = false;
    model.requestKey = "";
    model.selectedMethod = null;
    model.groupPaymentReference = null;
    model.pilgrimData = null;
    model.groupPilgrims.clear();
    selectedTrackingNos.clear();
    notifyListeners();
  }
}

// ----------------- Refund UI -----------------
class RefundScreen extends ConsumerStatefulWidget {
  const RefundScreen({super.key});
  @override
  ConsumerState<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends ConsumerState<RefundScreen> {
  final PageController _pageController = PageController();
  int _currentStep = -1;
  final _trackingController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _agencyIdController = TextEditingController();
  final _agencyNameController = TextEditingController();
  final _licenseController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _districtController = TextEditingController();
  final _branchController = TextEditingController();
  final _payOrderNameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void _showNotification(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step.clamp(0, 4));
    _pageController.jumpToPage(step);

    if (step == 3) {
      final controller = ref.read(refundControllerProvider);

      // Preload banks and agencies concurrently
      Future.wait([
        controller.loadBanks(),
        controller.loadHajjAgencies(),
      ]).then((_) {
        AppLoggerRefund.i(
            "💡 Preloaded Banks (${controller.bankList.length}) and Agencies (${controller.hajjAgencies.length})");
      }).catchError((e) {
        AppLoggerRefund.e("⛔ Error preloading banks/agencies: $e");
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _trackingController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _agencyIdController.dispose();
    _agencyNameController.dispose();
    _licenseController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _districtController.dispose();
    _branchController.dispose();
    _payOrderNameController.dispose();
    super.dispose();
  }

  bool _validatePaymentStep(RefundController controller) {
    final method = controller.model.selectedMethod;

    if (method == null) return false;

    switch (method) {
      case 'beftn':
        return controller.selectedAgency != null &&
            _accountNameController.text.trim().isNotEmpty &&
            _accountNumberController.text.trim().isNotEmpty &&
            controller.selectedBankItem != null &&
            controller.selectedDistrictItem != null &&
            controller.selectedBranchItem != null;

      case 'pay_order':
        return _payOrderNameController.text.trim().isNotEmpty;

      case 'hajj_agency':
        return controller.selectedAgency != null;

      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(refundControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Refund Request")),
      body: _currentStep == -1
          ? _stepRefundList(controller)
          : Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStepper(),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _step0(controller),
                      _step1(controller),
                      _step2AddPilgrim(controller),
                      _step3PaymentMethod(controller),
                      _step4Review(controller),
                    ],
                  ),
                ),
                if (_currentStep >= 0)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        if (_currentStep > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _goToStep(_currentStep - 1),
                              child: const Text("Previous"),
                            ),
                          ),
                        if (_currentStep > 0) const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontSize: 15),
                            ),
                            onPressed: () async {
                              final controller =
                                  ref.read(refundControllerProvider);
                              switch (_currentStep) {
                                case 0:
                                  final tracking =
                                      _trackingController.text.trim();
                                  final phone = _phoneController.text.trim();
                                  if (tracking.isEmpty || phone.isEmpty) {
                                    _showNotification(
                                        "Tracking number and phone are required");
                                    return;
                                  }
                                  try {
                                    const forWhat =
                                        "pre_registration"; // or "registration"
                                    final requestKey = await controller.sendOtp(
                                        tracking, phone, forWhat);
                                    _otpController.clear();
                                    _showNotification("OTP sent to $phone",
                                        success: true);
                                    _goToStep(1);
                                  } catch (e) {
                                    _showNotification("Failed to send OTP: $e");
                                  }
                                  break;

                                case 1:
                                  if (_otpController.text.trim().isEmpty) {
                                    _showNotification("Enter OTP");
                                    return;
                                  }
                                  try {
                                    final verified = await controller
                                        .verifyOtp(_otpController.text.trim());
                                    if (verified) {
                                      _showNotification("OTP verified",
                                          success: true);

                                      // ✅ Save the initial tracking number and preselect it
                                      final tracking =
                                          _trackingController.text.trim();
                                      controller.initialTrackingNo = tracking;
                                      controller.selectedTrackingNos
                                          .add(tracking);

                                      _goToStep(2); // go to pilgrims selection
                                    } else {
                                      _showNotification(
                                          "OTP verification failed");
                                    }
                                  } catch (e) {
                                    _showNotification(
                                        "Error verifying OTP: $e");
                                  }
                                  break;

                                case 2: // Pilgrims selected
                                  if (controller.selectedTrackingNos.isEmpty) {
                                    _showNotification(
                                        "Select at least one pilgrim");
                                    return;
                                  }
                                  _goToStep(3);
                                  break;

                                case 3: // Payment method step
                                  if (!_validatePaymentStep(controller)) {
                                    _showNotification(
                                        "Please fill all required fields for the selected payment method");
                                    return;
                                  }
                                  _goToStep(4);
                                  break;

                                case 4: // Review & Submit
                                  if (!_validatePaymentStep(controller)) {
                                    _showNotification(
                                        "Please fill all required fields for the selected payment method");
                                    return;
                                  }

                                  final agencyId =
                                      controller.selectedAgency != null
                                          ? int.tryParse(controller
                                              .selectedAgency!['id']
                                              .toString())
                                          : null;

                                  Map<String, dynamic>? paymentData;

                                  switch (controller.model.selectedMethod) {
                                    case 'beftn':
                                      paymentData = {
                                        'beftn_account_name':
                                            _accountNameController.text.trim(),
                                        'beftn_account_no':
                                            _accountNumberController.text
                                                .trim(),
                                        'beftn_bank_id': controller
                                                .selectedBankItem?['id'] ??
                                            0,
                                        'beftn_district_id': controller
                                                .selectedDistrictItem?['id'] ??
                                            0,
                                        'beftn_branch_id': controller
                                                .selectedBranchItem?['id'] ??
                                            0,
                                      };
                                      break;

                                    case 'pay_order':
                                      paymentData = {
                                        'pay_order_name':
                                            _payOrderNameController.text.trim(),
                                      };
                                      break;

                                    case 'hajj_agency':
                                      paymentData =
                                          {}; // agency_id is passed separately
                                      break;
                                  }

                                  try {
                                    final success =
                                        await controller.submitRefund(
                                      paymentData: paymentData,
                                      agencyId: agencyId,
                                    );
                                    if (success) {
                                      _showNotification(
                                          "Refund submitted successfully",
                                          success: true);
                                      controller.reset();
                                      _goToStep(-1);
                                    } else {
                                      _showNotification(
                                          "Failed to submit refund");
                                    }
                                  } catch (e) {
                                    _showNotification(
                                        "Error submitting refund: $e");
                                  }
                                  break;
                              }
                            },
                            child: Text(_currentStep == 4 ? "Submit" : "Next"),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildStepper() {
    const totalSteps = 5;
    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        // Odd indexes will be lines, even indexes will be step circles
        if (i.isEven) {
          final stepIndex = i ~/ 2;
          final isActive = stepIndex <= _currentStep;
          return CircleAvatar(
            radius: 14,
            backgroundColor: isActive ? Colors.green : Colors.grey.shade400,
            child: Text(
              "${stepIndex + 1}",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        } else {
          final lineIndex = (i - 1) ~/ 2;
          final isLineActive = lineIndex < _currentStep;
          return Expanded(
            child: Container(
              height: 3,
              color: isLineActive ? Colors.green : Colors.grey.shade300,
            ),
          );
        }
      }),
    );
  }

  int _getStepFromStatus(String? status) {
    switch (status) {
      case 'otp_verified':
        return 2; // Skip OTP steps, go directly to pilgrim selection
      case 'otp_sent':
        return 1; // OTP already sent, go to verification
      case 'pending':
      default:
        return 0; // Start from tracking & phone entry
    }
  }

  int _getPageIndexFromStep(String? status) {
    switch (status) {
      case 'otp_verified':
        return 0;
      case 'otp_sent':
        return 0;
      case 'pending':
      default:
        return 0;
    }
  }

  List<Widget> _buildPages(RefundController controller, String? status) {
    if (status == 'otp_verified') {
      // OTP already verified, skip tracking & OTP pages
      return [
        _step2AddPilgrim(controller),
        _step3PaymentMethod(controller),
        _step4Review(controller),
      ];
    } else if (status == 'otp_sent') {
      // OTP sent, start from OTP verification
      return [
        _step1(controller),
        _step2AddPilgrim(controller),
        _step3PaymentMethod(controller),
        _step4Review(controller),
      ];
    } else {
      // Start from tracking & phone entry
      return [
        _step0(controller),
        _step1(controller),
        _step2AddPilgrim(controller),
        _step3PaymentMethod(controller),
        _step4Review(controller),
      ];
    }
  }

  Widget _stepRefundList(RefundController controller) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: controller.fetchRefundList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var list = snapshot.data ?? [];

        // If no refunds found — create mock data
        // if (list.isEmpty) {
        //   list = [
        //     {
        //       "id": 10,
        //       "status": "submitted",
        //       "group_payment_reference": 9261,
        //       "tracking_no": "MOCKTRACKING1"
        //     },
        //     {
        //       "id": 10,
        //       "status": "pending",
        //       "group_payment_reference": 9261,
        //       "tracking_no": "MOCKTRACKING2"
        //     },
        //   ];
        // }

        // Refund list exists (real or mock): show list + Start New button
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Start New Refund"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {
                    controller.reset();
                    _goToStep(0); // Start from Step 0
                  },
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final refund = list[index];
                  final status =
                      refund['status']?.toString().toUpperCase() ?? "PENDING";
                  return ListTile(
                    title: Text("Tracking: ${refund['tracking_no']}"),
                    subtitle: Text("Status: $status"),
                    trailing: ElevatedButton(
                      onPressed: () {
                        final step =
                            _getStepFromStatus(refund['status']?.toString());
                        _goToStep(step);

                        // Preload data if OTP verified
                        if (refund['status'] == 'otp_verified') {
                          controller.model.requestKey =
                              refund['request_key'] ?? '';
                          controller.model.otpVerified = true;
                          controller.model.pilgrimData =
                              refund['pilgrim_info'] != null
                                  ? Map<String, dynamic>.from(
                                      refund['pilgrim_info'])
                                  : null;
                          controller.model.groupPilgrims =
                              List<Map<String, dynamic>>.from(
                                  refund['group_pilgrim_list'] ?? []);
                        }
                      },
                      child: const Text("Resume Refund"),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _step0(RefundController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        TextField(
            controller: _trackingController,
            decoration: const InputDecoration(labelText: "Tracking Number")),
        const SizedBox(height: 16),
        TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: "Phone Number")),
      ]),
    );
  }

  Widget _step1(RefundController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Enter OTP",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "We’ve sent a 6-digit OTP to your phone number.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // --- OTP Fields (6 boxes) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 45,
                child: TextField(
                  maxLength: 1,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    counterText: "",
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.green, width: 2),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty && index < 5) {
                      FocusScope.of(context).nextFocus();
                    }
                    if (val.isEmpty && index > 0) {
                      FocusScope.of(context).previousFocus();
                    }

                    // Update OTP controller text
                    final otp = _otpController.text.split('');
                    if (otp.length < 6) {
                      otp.addAll(List.filled(6 - otp.length, ''));
                    }
                    otp[index] = val;
                    _otpController.text = otp.join();
                  },
                ),
              );
            }),
          ),

          const SizedBox(height: 32),

          // --- Resend OTP ---
          TextButton.icon(
            icon: const Icon(Icons.refresh, color: Colors.green),
            label: const Text(
              "Resend OTP",
              style:
                  TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final tracking = _trackingController.text.trim();
              final phone = _phoneController.text.trim();
              if (tracking.isEmpty || phone.isEmpty) {
                _showNotification("Enter tracking and phone first");
                return;
              }

              try {
                const forWhat = "pre_registration";
                await controller.sendOtp(tracking, phone, forWhat);
                _showNotification("OTP resent successfully", success: true);
              } catch (e) {
                _showNotification("Failed to resend OTP: $e");
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _step2AddPilgrim(RefundController controller) {
    final pilgrims = controller.model.groupPilgrims;
    if (pilgrims.isEmpty) {
      return const Center(child: Text("No pilgrims found"));
    }

    return ListView.builder(
      itemCount: pilgrims.length,
      itemBuilder: (context, index) {
        final pilgrim = pilgrims[index];
        final tracking = pilgrim['tracking_no'] ?? '';
        final name = pilgrim['full_name_english'] ??
            pilgrim['full_name_bangla'] ??
            'Unknown';

        final isInitial = tracking == controller.initialTrackingNo; // ✅
        final isSelected = controller.isPilgrimSelected(tracking);

        return CheckboxListTile(
          title: Text(
            name,
            style: TextStyle(
              color: isInitial ? Colors.grey.shade600 : null,
              fontWeight: isInitial ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          // subtitle: isInitial
          //     ? const Text("(Main tracking — cannot unselect)",
          //         style: TextStyle(color: Colors.grey, fontSize: 12))
          //     : null,
          value: isSelected,
          onChanged: isInitial
              ? null // ✅ disable unselecting
              : (v) => controller.togglePilgrimSelection(tracking, v ?? false),
        );
      },
    );
  }

  Widget _step3PaymentMethod(RefundController controller) {
    bool validatePaymentMethod(RefundController controller) {
      final method = controller.model.selectedMethod;

      if (method == null) return false;

      switch (method) {
        case 'beftn':
          if (controller.selectedAgency == null) return false;
          if (_accountNameController.text.trim().isEmpty) return false;
          if (_accountNumberController.text.trim().isEmpty) return false;
          if (controller.selectedBankItem == null) return false;
          if (controller.selectedDistrictItem == null) return false;
          if (controller.selectedBranchItem == null) return false;
          return true;

        case 'pay_order':
          if (_payOrderNameController.text.trim().isEmpty) return false;
          return true;

        case 'hajj_agency':
          if (controller.selectedAgency == null) return false;
          return true;

        default:
          return false;
      }
    }

    // --- Agency Dropdown ---
    Widget agencyDropdown() {
      if (controller.hajjAgencies.isEmpty)
        return const CircularProgressIndicator();

      return DropdownButtonFormField<int>(
        value: controller.selectedAgency != null
            ? int.tryParse(controller.selectedAgency!['id'].toString())
            : null,
        hint: const Text("Select Agency"),
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        items: controller.hajjAgencies.map((a) {
          return DropdownMenuItem<int>(
            value: int.tryParse(a['id'].toString()),
            child: Text(a['name'] ?? ''),
          );
        }).toList(),
        onChanged: (val) {
          if (val == null) return;
          final agency = controller.hajjAgencies
              .firstWhere((a) => int.tryParse(a['id'].toString()) == val);
          controller.setSelectedAgency(agency);
        },
      );
    }

    // --- Bank Dropdown ---
    Widget bankDropdown() {
      if (controller.bankList.isEmpty) return const CircularProgressIndicator();

      return DropdownButtonFormField<int>(
        value: controller.selectedBankItem != null
            ? controller.selectedBankItem!['id'] as int
            : null,
        hint: const Text("Select Bank"),
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        items: controller.bankList.map((b) {
          return DropdownMenuItem<int>(
            value: b['id'] as int,
            child: Text(b['title'] ?? ''),
          );
        }).toList(),
        onChanged: (val) async {
          if (val == null) return;
          final bank = controller.bankList.firstWhere((b) => b['id'] == val);
          await controller.setSelectedBank(bank);
        },
      );
    }

    // --- District Dropdown ---
    Widget districtDropdown() {
      if (controller.districtList.isEmpty)
        return const CircularProgressIndicator();

      return DropdownButtonFormField<int>(
        value: controller.selectedDistrictItem != null
            ? controller.selectedDistrictItem!['id'] as int
            : null,
        hint: const Text("Select District"),
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        items: controller.districtList.map((d) {
          return DropdownMenuItem<int>(
            value: d['id'] as int,
            child: Text(d['title'] ?? ''),
          );
        }).toList(),
        onChanged: (val) async {
          if (val == null) return;
          final district =
              controller.districtList.firstWhere((d) => d['id'] == val);
          await controller.setSelectedDistrict(district);
        },
      );
    }

    // --- Branch Dropdown ---
    Widget branchDropdown() {
      if (controller.branchList.isEmpty)
        return const CircularProgressIndicator();

      return DropdownButtonFormField<int>(
        value: controller.selectedBranchItem != null
            ? controller.selectedBranchItem!['id'] as int
            : null,
        hint: const Text("Select Branch"),
        isExpanded: true,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        items: controller.branchList.map((b) {
          return DropdownMenuItem<int>(
            value: b['id'] as int,
            child: Text(b['title'] ?? ''),
          );
        }).toList(),
        onChanged: (val) {
          if (val == null) return;
          final branch =
              controller.branchList.firstWhere((b) => b['id'] == val);
          controller.setSelectedBranch(branch);
        },
      );
    }

    // --- Payment Type Buttons ---
    Widget paymentTypeSelector() {
      final paymentMethods = {
        'beftn': 'Bank Transfer (BEFTN)',
        'pay_order': 'Pay Order',
        'hajj_agency': 'Hajj Agency',
      };

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: paymentMethods.entries.map((entry) {
          final isSelected = controller.model.selectedMethod == entry.key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isSelected ? Colors.blue : Colors.grey.shade200,
                  foregroundColor: isSelected ? Colors.white : Colors.black87,
                ),
                onPressed: () => controller.setSelectedMethod(entry.key),
                child: Text(
                  entry.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    // --- Conditional Form Section ---
    Widget paymentForm() {
      final selected = controller.model.selectedMethod;
      if (selected == null) return const SizedBox();

      if (selected == 'pay_order' || selected == 'hajj_agency') {
        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  "This payment method is currently unavailable. Please use Bank Transfer (BEFTN).",
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        );
      }

      // Bank Transfer Form
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          agencyDropdown(),
          const SizedBox(height: 12),
          TextField(
            controller: _accountNameController,
            decoration: const InputDecoration(labelText: "Account Name"),
          ),
          TextField(
            controller: _accountNumberController,
            decoration: const InputDecoration(labelText: "Account Number"),
          ),
          const SizedBox(height: 12),
          bankDropdown(),
          const SizedBox(height: 8),
          districtDropdown(),
          const SizedBox(height: 8),
          branchDropdown(),
        ],
      );
    }

    // --- Main UI ---
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Payment Method",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          paymentTypeSelector(),
          const SizedBox(height: 16),
          paymentForm(),
        ],
      ),
    );
  }

  Widget _step4Review(RefundController controller) {
    Map<String, dynamic> paymentDataPreview = {};
    if (controller.model.selectedMethod == "beftn") {
      paymentDataPreview = {
        'Agency ID': controller.selectedAgency?['id'] ?? '-',
        'Agency Name': controller.selectedAgency?['name'] ?? '-',
        'Account Name': _accountNameController.text,
        'Account Number': _accountNumberController.text,
        'Bank': controller.selectedBankItem?['title'] ?? '-',
        'Bank ID': controller.selectedBankItem?['id'] ?? 0,
        'District': controller.selectedDistrictItem?['title'] ?? '-',
        'District ID': controller.selectedDistrictItem?['id'] ?? 0,
        'Branch': controller.selectedBranchItem?['title'] ?? '-',
        'Branch ID': controller.selectedBranchItem?['id'] ?? 0,
      };
    } else if (controller.model.selectedMethod == "pay_order") {
      paymentDataPreview = {
        'Agency ID': controller.selectedAgency?['id'] ?? '-',
        'Agency Name': controller.selectedAgency?['name'] ?? '-',
        'Pay Order Name': _payOrderNameController.text,
      };
    } else if (controller.model.selectedMethod == "hajj_agency") {
      paymentDataPreview = {
        'Agency ID': controller.selectedAgency?['id'] ?? '-',
        'Agency Name': controller.selectedAgency?['name'] ?? '-',
      };
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Selected Method: ${controller.model.selectedMethod ?? '-'}"),
          const SizedBox(height: 8),
          Text(
              "Selected Pilgrims: ${controller.selectedTrackingNos.join(', ')}"),
          const SizedBox(height: 16),
          const Text("Payment Details:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          ...paymentDataPreview.entries
              .map((e) => Text("${e.key}: ${e.value}")),
        ],
      ),
    );
  }
}
