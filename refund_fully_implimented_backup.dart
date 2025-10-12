import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labbayk/features/auth/providers/login_provider.dart';

// ----------------- Logger -----------------
class AppLogger {
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
      AppLogger.i("⏳ [API REQUEST] GET $url");
      final res = await dio.get(url,
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      AppLogger.i("✅ [API RESPONSE] ${res.statusCode} $url\nData: ${res.data}");
      return res.data ?? [];
    } catch (e) {
      AppLogger.e("Fetch refund list error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchRefundDetail(Ref ref, int refundId) async {
    final token = ref.read(authTokenProvider);
    final url = '/v2/user/refunds/$refundId';
    try {
      AppLogger.i("⏳ [API REQUEST] GET $url");
      final res = await dio.get(url,
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      AppLogger.i("✅ [API RESPONSE] ${res.statusCode} $url\nData: ${res.data}");
      if (res.data != null && res.data is Map) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (e) {
      AppLogger.e("Fetch refund detail error: $e");
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
      AppLogger.e(errorMsg);
      throw ArgumentError(errorMsg);
    }

    final body = {'tracking_no': trackingNo, 'phone': phone, 'for': forWhat};

    try {
      AppLogger.i(
          "⏳ [API REQUEST] POST $url\nHeaders: Authorization: Bearer $token\nData: $body");
      final res = await dio.post(
        url,
        data: jsonEncode(body),
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      AppLogger.i(
          "💡 [API RESPONSE] ${res.statusCode} $url\nData: ${res.data}");
      if (res.statusCode == 200) {
        final requestKey = res.data['request_key'];
        if (requestKey == null)
          throw Exception("API did not return request_key");
        return requestKey;
      } else if (res.statusCode == 422 || res.statusCode == 400) {
        throw Exception(res.data['error'] ?? 'Validation or bad request');
      } else {
        throw Exception('Unexpected error ${res.statusCode}: ${res.data}');
      }
    } catch (e) {
      AppLogger.e("⛔ Send OTP error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> verifyOtp(
      Ref ref, String requestKey, String otp) async {
    final token = ref.read(authTokenProvider);
    final url = '/v2/user/refunds/verify_otp';
    final body = {'request_key': requestKey, 'otp': otp};

    try {
      AppLogger.i("⏳ [API REQUEST] POST $url\nData: $body");
      final res = await dio.post(
        url,
        data: jsonEncode(body),
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      AppLogger.i(
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
      AppLogger.e("⛔ Verify OTP error: $e");
      rethrow;
    }
  }

  Future<bool> submitRefundWithDirectFields(
      Ref ref, Map<String, dynamic> body) async {
    final token = ref.read(authTokenProvider);
    final url = '/v2/user/refunds/submit';

    try {
      AppLogger.i("⏳ [API REQUEST] POST $url\nData: $body");
      final res = await dio.post(
        url,
        data: jsonEncode(body),
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json'
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      AppLogger.i(
          "💡 [API RESPONSE] ${res.statusCode} $url\nData: ${res.data}");
      if (res.statusCode == 200) return true;
      final error = res.data['error'] ?? 'Validation or bad request';
      throw Exception(error);
    } catch (e) {
      AppLogger.e("⛔ Submit refund error: $e");
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
      if (res.statusCode == 200 && res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return [];
    } catch (e) {
      AppLogger.e("Fetch Hajj Agencies error: $e");
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

  List<Map<String, dynamic>> hajjAgencies = [];
  Map<String, dynamic>? selectedAgency;

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

  Future<void> loadHajjAgencies() async {
    hajjAgencies = await apiClient.fetchHajjAgencies(ref);
    notifyListeners();
  }

  // ----------------- Fetch Refunds -----------------
  Future<List<Map<String, dynamic>>> fetchRefundList() async {
    try {
      final list = await apiClient.fetchRefundList(ref);
      return (list ?? [])
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      AppLogger.e("Controller fetchRefundList error: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchRefundDetail(int refundId) async {
    try {
      return await apiClient.fetchRefundDetail(ref, refundId);
    } catch (e) {
      AppLogger.e("Controller fetchRefundDetail error: $e");
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
      AppLogger.e("⛔ Payment method is not selected");
      return false;
    }

    // Add agency_id if Hajj Agency or any explicit agency

    // ---------------- Prepare request body ----------------
    final Map<String, dynamic> requestBody = {
      'request_key': model.requestKey,
      'tracking_nos': selectedTrackingNos.toList(),
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
      AppLogger.e("⛔ Submit refund error: $e");
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
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _districtController.dispose();
    _branchController.dispose();
    _payOrderNameController.dispose();
    super.dispose();
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

                                case 3: // Payment method
                                  if (controller.model.selectedMethod == null) {
                                    _showNotification(
                                        "Select a payment method");
                                    return;
                                  }
                                  _goToStep(4);
                                  break;

                                case 4: // Review & Submit
                                case 4: // Review & Submit
                                  if (controller.model.selectedMethod == null) {
                                    _showNotification(
                                        "Select a payment method");
                                    return;
                                  }

                                  final agencyId = int.tryParse(
                                      _agencyIdController.text.trim());

                                  Map<String, dynamic>? paymentData;

                                  switch (controller.model.selectedMethod) {
                                    case 'beftn':
                                      paymentData = {
                                        'beftn_account_name':
                                            _accountNumberController.text
                                                .trim(),
                                        'beftn_account_no':
                                            _accountNumberController.text
                                                .trim(),
                                        'beftn_bank_id': int.tryParse(
                                                _bankNameController.text
                                                    .trim()) ??
                                            0,
                                        'beftn_district_id': int.tryParse(
                                                _districtController.text
                                                    .trim()) ??
                                            0,
                                        'beftn_branch_id': int.tryParse(
                                                _branchController.text
                                                    .trim()) ??
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
                                          {}; // only agency_id is outside
                                      break;
                                  }

                                  try {
                                    final success =
                                        await controller.submitRefund(
                                      paymentData: paymentData,
                                      agencyId:
                                          agencyId, // <-- pass agency_id separately
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
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (i) {
          return CircleAvatar(
            radius: 12,
            backgroundColor: i <= _currentStep ? Colors.green : Colors.grey,
            child: Text(
              "$i",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          );
        }));
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
        final list = snapshot.data ?? [];
        if (list.isEmpty) return const Center(child: Text("No refunds found"));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Start New Refund"),
                  onPressed: () {
                    controller.reset();
                    _goToStep(0); // start from step 0 for new refund
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
      child: Column(children: [
        TextField(
            controller: _otpController,
            decoration: const InputDecoration(labelText: "Enter OTP")),
      ]),
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
        return CheckboxListTile(
          title: Text(name),
          value: controller.isPilgrimSelected(tracking),
          onChanged: (v) =>
              controller.togglePilgrimSelection(tracking, v ?? false),
        );
      },
    );
  }

  Widget _step3PaymentMethod(RefundController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select Payment Method",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          // Bank Transfer (BEFTN)
          RadioListTile<String>(
            title: const Text("Bank Transfer (BEFTN)"),
            value: "beftn",
            groupValue: controller.model.selectedMethod,
            onChanged: controller.setSelectedMethod,
          ),
          if (controller.model.selectedMethod == "beftn") ...[
            TextField(
                controller: _agencyIdController,
                decoration: const InputDecoration(labelText: "Agency ID")),
            TextField(
                controller: _accountNumberController,
                decoration: const InputDecoration(labelText: "Account Name")),
            TextField(
                controller: _accountNumberController,
                decoration: const InputDecoration(labelText: "Account Number")),
            TextField(
                controller: _bankNameController,
                decoration: const InputDecoration(labelText: "Bank ID")),
            TextField(
                controller: _districtController,
                decoration: const InputDecoration(labelText: "District ID")),
            TextField(
                controller: _branchController,
                decoration: const InputDecoration(labelText: "Branch ID")),
          ],

          // Pay Order
          RadioListTile<String>(
            title: const Text("Pay Order"),
            value: "pay_order",
            groupValue: controller.model.selectedMethod,
            onChanged: controller.setSelectedMethod,
          ),
          if (controller.model.selectedMethod == "pay_order") ...[
            TextField(
                controller: _agencyIdController,
                decoration: const InputDecoration(labelText: "Agency ID")),
            TextField(
                controller: _payOrderNameController,
                decoration: const InputDecoration(labelText: "Pay Order Name")),
          ],

          // Hajj Agency
          RadioListTile<String>(
            title: const Text("Hajj Agency"),
            value: "hajj_agency",
            groupValue: controller.model.selectedMethod,
            onChanged: controller.setSelectedMethod,
          ),
          if (controller.model.selectedMethod == "hajj_agency") ...[
            TextField(
                controller: _agencyIdController,
                decoration: const InputDecoration(labelText: "Agency ID")),
          ],
        ],
      ),
    );
  }

  Widget _step4Review(RefundController controller) {
    Map<String, dynamic> paymentDataPreview = {};
    if (controller.model.selectedMethod == "beftn") {
      paymentDataPreview = {
        'Agency ID': _agencyIdController.text,
        'Account Name': _accountNumberController.text,
        'Account Number': _accountNumberController.text,
        'Bank ID': _bankNameController.text,
        'District ID': _districtController.text,
        'Branch ID': _branchController.text,
      };
    } else if (controller.model.selectedMethod == "pay_order") {
      paymentDataPreview = {
        'Agency ID': _agencyIdController.text,
        'Pay Order Name': _payOrderNameController.text,
      };
    } else if (controller.model.selectedMethod == "hajj_agency") {
      paymentDataPreview = {
        'Agency ID': _agencyIdController.text,
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
