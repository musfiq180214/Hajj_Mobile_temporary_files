import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:labbayk/core/utils/logger.dart';
import 'package:labbayk/core/constants/urls.dart';
import 'package:labbayk/features/auth/providers/login_provider.dart';
import 'package:labbayk/features/pre_registration/domain/pre_reg_list.dart';
import 'package:labbayk/features/pre_registration/providers/pre_registration_provider.dart';

/// ----------------- MODEL -----------------
class RefundModel {
  Pilgrim? pilgrim;
  bool otpSent = false;
  bool otpVerified = false;
  String requestKey = "";
  String? selectedMethod;
  int? refundId;

  RefundModel({this.pilgrim});
}

/// ----------------- API CLIENT -----------------
class RefundApiClient {
  final Ref ref;
  RefundApiClient(this.ref);

  Dio get _dio {
    final token = ref.read(authTokenProvider);
    final dio = Dio(BaseOptions(
      baseUrl: baseUrlDevelopment,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          AppLogger.i("➡️ REQUEST [${options.method}] ${options.uri}");
          AppLogger.i("Headers: ${options.headers}");
          AppLogger.i("Data: ${options.data}");
          return handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.i(
              "✅ RESPONSE [${response.statusCode}] ${response.requestOptions.uri}");
          AppLogger.i("Data: ${response.data}");
          return handler.next(response);
        },
        onError: (e, handler) {
          AppLogger.e(
              "❌ ERROR [${e.response?.statusCode}] ${e.requestOptions.uri}");
          AppLogger.e("Message: ${e.message}");
          if (e.response != null) AppLogger.e("Data: ${e.response?.data}");
          return handler.next(e);
        },
      ),
    );

    return dio;
  }

  Future<String?> sendOtp(String trackingNo, String phone) async {
    try {
      final response = await _dio.post(
        '/v2/user/refunds/get_otp',
        data: {
          'tracking_no': trackingNo,
          'phone': phone,
          'for': 'pre_registration'
        },
        options: Options(validateStatus: (status) => true),
      );

      final data = response.data;
      String requestKey = "";
      if (data is Map && data.containsKey('request_key')) {
        requestKey = (data['request_key'] ?? "").toString();
      }
      return requestKey.isNotEmpty ? requestKey : null;
    } catch (e) {
      AppLogger.e("❌ Error sending OTP: $e");
      return null;
    }
  }

  Future<int?> verifyOtp(String requestKey, String otp) async {
    try {
      final response = await _dio.post(
        '/v2/user/refunds/verify_otp',
        data: {'request_key': requestKey, 'otp': otp},
        options: Options(validateStatus: (status) => true),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data['id'] != null ? int.tryParse(data['id'].toString()) : null;
      }
      return null;
    } catch (e) {
      AppLogger.e("❌ Error verifying OTP: $e");
      return null;
    }
  }

  Future<bool> addPilgrim(int refundId, String trackingNo) async {
    try {
      final response = await _dio.put(
        '/v2/user/refunds/$refundId/add_pilgrim/',
        data: {'tracking_no': trackingNo},
        options: Options(validateStatus: (status) => true),
      );

      if (response.statusCode == 200) return true;
      AppLogger.e("❌ Add Pilgrim failed: ${response.data}");
      return false;
    } catch (e) {
      AppLogger.e("❌ Error adding pilgrim: $e");
      return false;
    }
  }

  Future<bool> addPaymentInfo(
      int refundId, Map<String, dynamic> payload) async {
    try {
      final response = await _dio.put(
        '/v2/user/refunds/$refundId/add_payment_info/',
        data: payload,
        options: Options(validateStatus: (status) => true),
      );
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e("❌ Error adding payment info: $e");
      return false;
    }
  }

  Future<bool> submitRefund(int refundId) async {
    try {
      final response = await _dio.post(
        '/v2/user/refunds/$refundId/submit',
        options: Options(validateStatus: (status) => true),
      );

      AppLogger.i("➡️ Submit Refund REQUEST:");
      AppLogger.i(
          "URL: ${_dio.options.baseUrl}/v2/user/refunds/$refundId/submit");
      AppLogger.i("Headers: ${_dio.options.headers}");
      AppLogger.i("Body: none");

      AppLogger.i("✅ Submit Refund RESPONSE:");
      AppLogger.i("Status Code: ${response.statusCode}");
      AppLogger.i("Data: ${response.data}");
      AppLogger.i("Headers: ${response.headers.map}");

      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e("❌ Error submitting refund: $e");
      return false;
    }
  }
}

/// ----------------- CONTROLLER -----------------
class RefundController extends ChangeNotifier {
  final Ref ref;
  final RefundApiClient apiClient;
  final RefundModel model = RefundModel();

  RefundController(this.ref) : apiClient = RefundApiClient(ref);

  void setPilgrim(Pilgrim? pilgrim) {
    model.pilgrim = pilgrim;
    notifyListeners();
  }

  void setSelectedMethod(String method) {
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

  void reset() {
    model.pilgrim = null;
    model.otpSent = false;
    model.otpVerified = false;
    model.requestKey = "";
    model.selectedMethod = null;
    model.refundId = null;
    notifyListeners();
  }

  Future<bool> sendOtp(String trackingNo, String phone) async {
    final key = await apiClient.sendOtp(trackingNo, phone);
    if (key != null) {
      setRequestKey(key);
      setOtpSent(true);
      return true;
    }
    return false;
  }

  Future<bool> verifyOtp(String otp) async {
    if (model.requestKey.isEmpty) return false;
    final refundId = await apiClient.verifyOtp(model.requestKey, otp);
    if (refundId != null) {
      model.refundId = refundId;
      setOtpVerified(true);
      return true;
    }
    return false;
  }

  Future<bool> addPilgrim(String trackingNo) async {
    if (model.refundId == null) return false;
    return await apiClient.addPilgrim(model.refundId!, trackingNo);
  }

  Future<bool> addPaymentInfo({
    required String? paymentMethod,
    String? agencyId,
    String? agencyName,
    String? license,
    String? accountNo,
    String? bankId,
    String? districtId,
    String? branchId,
    String? payOrderName,
  }) async {
    if (model.refundId == null) return false;

    final payload = <String, dynamic>{};

    switch (paymentMethod) {
      case "Hajj_Agency":
        payload.addAll({
          'payment_type': 'hajj_agency',
          'agency_id': int.tryParse(agencyId ?? '') ?? 0,
        });
        break;
      case "Pay_Order":
        payload.addAll({
          'payment_type': 'pay_order',
          'pay_order_name': payOrderName ?? '',
        });
        break;
      case "BEFTN":
        payload.addAll({
          'payment_type': 'beftn',
          'beftn_account_name': agencyName ?? '',
          'beftn_account_no': accountNo ?? '',
          'beftn_bank_id': int.tryParse(bankId ?? '') ?? 0,
          'beftn_district_id': int.tryParse(districtId ?? '') ?? 0,
          'beftn_branch_id': int.tryParse(branchId ?? '') ?? 0,
        });
        break;
      default:
        return false;
    }

    return await apiClient.addPaymentInfo(model.refundId!, payload);
  }

  Future<bool> submitRefund() async {
    if (model.refundId == null) return false;
    return await apiClient.submitRefund(model.refundId!);
  }
}

/// ----------------- PROVIDER -----------------
final refundControllerProvider =
    ChangeNotifierProvider((ref) => RefundController(ref));

class RefundScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends ConsumerState<RefundScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

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

  @override
  void initState() {
    super.initState();
    _trackingController.addListener(() => setState(() {}));
    _phoneController.addListener(() => setState(() {}));
    _otpController.addListener(() => setState(() {}));
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

  void _showNotification(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? Colors.green : Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step.clamp(0, 5));
    _pageController.jumpToPage(_currentStep);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(refundControllerProvider);
    final model = controller.model;

    return Scaffold(
      appBar: AppBar(title: const Text("Refund Request")),
      body: Column(
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
                _step2(controller),
                _step3AddPilgrim(controller),
                _step4PaymentInfo(controller),
                _step5Submit(controller),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => _goToStep(_currentStep - 1),
                        child: const Text("Back")),
                  ),
                if (_currentStep > 0) const SizedBox(width: 8),
                Expanded(child: _buildPrimaryArea(controller)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    final steps = ['1', '2', '3', '4', '5', '6'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isEven) {
          int stepIndex = index ~/ 2;
          bool isActive = stepIndex <= _currentStep;
          return CircleAvatar(
            radius: 16,
            backgroundColor: isActive ? Colors.blue : Colors.grey.shade300,
            child: Text(
              steps[stepIndex],
              style: TextStyle(
                  color: isActive ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.bold),
            ),
          );
        } else {
          bool isActive = (index ~/ 2) < _currentStep;
          return Expanded(
              child: Container(
                  height: 3,
                  color: isActive ? Colors.blue : Colors.grey.shade300));
        }
      }),
    );
  }

  Widget _buildPrimaryArea(RefundController controller) {
    final model = controller.model;

    switch (_currentStep) {
      case 0:
        final canNext = _trackingController.text.trim().isNotEmpty;
        return ElevatedButton(
          onPressed: canNext ? () => _goToStep(1) : null,
          child: const Text("Next"),
        );
      case 1:
        final canSendOtp = _phoneController.text.trim().isNotEmpty &&
            _trackingController.text.trim().isNotEmpty;
        final canVerify =
            model.otpSent && _otpController.text.trim().isNotEmpty;

        return Row(
          children: [
            Expanded(
                child: ElevatedButton(
              onPressed: canSendOtp
                  ? () async {
                      final success = await controller.sendOtp(
                        _trackingController.text.trim(),
                        _phoneController.text.trim(),
                      );
                      if (success) {
                        _showNotification("OTP sent", success: true);
                        setState(() {});
                      } else {
                        _showNotification("Failed to send OTP");
                      }
                    }
                  : null,
              child: Text("Send"),
            )),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: canVerify
                    ? () async {
                        final success = await controller.verifyOtp(
                          _otpController.text.trim(),
                        );
                        if (success) {
                          _showNotification("OTP verified", success: true);
                          _goToStep(2);
                        } else {
                          _showNotification("Invalid OTP");
                        }
                      }
                    : null,
                child: const Text("Verify"),
              ),
            ),
          ],
        );
      case 2:
        return ElevatedButton(
            onPressed: () => _goToStep(3),
            child: const Text("Next: Add Pilgrim"));
      case 3:
        // Bottom button should always say NEXT
        return ElevatedButton(
          onPressed: () => _goToStep(4),
          child: const Text("Next"),
        );

      case 4:
        return ElevatedButton(
            onPressed: () async {
              if (controller.model.selectedMethod == null) {
                _showNotification("Select payment method");
                return;
              }
              final success = await controller.addPaymentInfo(
                paymentMethod: controller.model.selectedMethod,
                agencyId: _agencyIdController.text.trim(),
                agencyName: _agencyNameController.text.trim(),
                license: _licenseController.text.trim(),
                accountNo: _accountNumberController.text.trim(),
                bankId: _bankNameController.text.trim(),
                districtId: _districtController.text.trim(),
                branchId: _branchController.text.trim(),
                payOrderName: _payOrderNameController.text.trim(),
              );
              if (success) {
                _showNotification("Payment info added successfully",
                    success: true);
                _goToStep(5);
              } else {
                _showNotification("Failed to add payment info");
              }
            },
            child: const Text("Add Payment Info"));
      case 5:
        return ElevatedButton(
            onPressed: () async {
              final success = await controller.submitRefund();
              if (success) {
                _showNotification("Refund submitted successfully",
                    success: true);
                controller.reset();
                _trackingController.clear();
                _phoneController.clear();
                _otpController.clear();
                _agencyIdController.clear();
                _agencyNameController.clear();
                _licenseController.clear();
                _accountNumberController.clear();
                _bankNameController.clear();
                _districtController.clear();
                _branchController.clear();
                _payOrderNameController.clear();
                _goToStep(0);
              } else {
                _showNotification("Refund submission failed");
              }
            },
            child: const Text("Submit Refund"));
      default:
        return ElevatedButton(
          onPressed: () => _goToStep(_currentStep + 1),
          child: const Text("Next"),
        );
    }
  }

  // ----------------- STEP WIDGETS -----------------
  Widget _step0(RefundController controller) {
    final list = ref.watch(preRegListProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _trackingController,
            decoration: const InputDecoration(
                labelText: "Tracking Number", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: list.when(
                data: (data) => data.isNotEmpty
                    ? ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          final item = data[index];
                          return Card(
                            child: ListTile(
                              title: Text(item.name ?? ""),
                              subtitle: Text(item.trackingNo ?? ""),
                              onTap: () {
                                controller.setPilgrim(item);
                                _trackingController.text =
                                    item.trackingNo ?? "";
                                setState(() {});
                              },
                            ),
                          );
                        },
                      )
                    : const Center(child: Text("No data found")),
                error: (e, _) => Center(child: Text("Error: $e")),
                loading: () =>
                    const Center(child: CircularProgressIndicator())),
          ),
        ],
      ),
    );
  }

  Widget _step1(RefundController controller) {
    final model = controller.model;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: "Phone Number", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          if (model.otpSent)
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Enter OTP", border: OutlineInputBorder()),
            ),
          if (model.otpSent)
            const SizedBox(
              height: 12,
            ),
          if (model.otpSent)
            const Text(
              "OTP has been sent to your phone. Enter it above and tap Verify & Next.",
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  Widget _step2(RefundController controller) {
    return Center(
      child: Text(
        "OTP Verified! Proceed to add pilgrim.",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _step3AddPilgrim(RefundController controller) {
    final list = ref.watch(preRegListProvider);
    final TextEditingController trackingController = _trackingController;

    // Keep a local list of added pilgrims for display
    final List<String> addedPilgrims = [];

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add Pilgrim (Optional)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Input field + Add button
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: trackingController,
                      decoration: const InputDecoration(
                        labelText: "Pilgrim Tracking Number",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final trackingNo = trackingController.text.trim();
                      if (trackingNo.isEmpty) {
                        _showNotification(
                            "Enter a tracking number to add pilgrim");
                        return;
                      }

                      final success = await controller.addPilgrim(trackingNo);
                      if (success) {
                        _showNotification(
                          "Pilgrim '$trackingNo' added successfully",
                          success: true,
                        );
                        addedPilgrims.add(trackingNo);
                        trackingController.clear();
                        setState(() {});
                      } else {
                        _showNotification(
                            "Failed to add pilgrim '$trackingNo'");
                      }
                    },
                    child: const Text("Add Pilgrim"),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                "Pilgrims List (Tap to fill Tracking Number above):",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // List of all pilgrims
              Expanded(
                child: list.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return const Center(child: Text("No pilgrims found"));
                    }
                    return ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final pilgrim = data[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(pilgrim.name ?? ""),
                            subtitle: Text(
                                "Tracking No: ${pilgrim.trackingNo ?? ""}"),
                            onTap: () {
                              trackingController.text =
                                  pilgrim.trackingNo ?? "";
                              setState(() {});
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text("Error: $e")),
                ),
              ),

              const SizedBox(height: 16),

              // Optional: show added pilgrims below
              if (addedPilgrims.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Added Pilgrims:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...addedPilgrims.map((tracking) => Card(
                          child: ListTile(
                            title: Text("Tracking No: $tracking"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  addedPilgrims.remove(tracking);
                                });
                              },
                            ),
                          ),
                        )),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  // Widget _step4PaymentInfo(RefundController controller) {
  //   // existing Step3 content goes here (Payment Info)
  //   return Center(child: Text("Payment Info Step"));
  // }

  // Widget _step5Submit(RefundController controller) {
  //   return Center(
  //     child: Text(
  //       "Review your payment info and click Submit",
  //       style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  //     ),
  //   );
  // }

  Widget _step4PaymentInfo(RefundController controller) {
    final _formKey = GlobalKey<FormState>();
    final dio = Dio(BaseOptions(
      baseUrl: baseUrlDevelopment,
      headers: {
        'Authorization': 'Bearer ${ref.read(authTokenProvider)}',
        'Content-Type': 'application/json',
      },
    ));

    Future<List<dynamic>> fetchAgencies() async {
      final res = await dio.get('/v2/user/dropdown/agencies');
      if (res.statusCode == 200 && res.data is List) return res.data;
      return [];
    }

    Future<List<dynamic>> fetchBanks() async {
      final res = await dio.get('/v2/user/dropdown/banks');
      if (res.statusCode == 200 && res.data is List) return res.data;
      return [];
    }

    Future<List<dynamic>> fetchDistricts(int bankId) async {
      final res = await dio.get('/v2/user/dropdown/bank_districts',
          queryParameters: {'bank_id': bankId});
      if (res.statusCode == 200 && res.data is List) return res.data;
      return [];
    }

    Future<List<dynamic>> fetchBranches(int bankId, int districtId) async {
      final res = await dio.get('/v2/user/dropdown/bank_branches',
          queryParameters: {'bank_id': bankId, 'district_id': districtId});
      if (res.statusCode == 200 && res.data is List) return res.data;
      return [];
    }

    return FutureBuilder<List<dynamic>>(
      future: fetchAgencies(),
      builder: (context, agencySnap) {
        if (agencySnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (agencySnap.hasError) {
          return const Center(child: Text("Failed to load agency data"));
        }

        final agencies = agencySnap.data ?? [];

        return Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Select Payment Method",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _methodButton("Hajj_Agency", "Hajj Agency", controller),
                    const SizedBox(width: 8),
                    _methodButton("BEFTN", "BEFTN", controller),
                    const SizedBox(width: 8),
                    _methodButton("Pay_Order", "Pay Order", controller),
                  ],
                ),
                const SizedBox(height: 16),

                /// ============== HAJJ AGENCY ==============
                if (controller.model.selectedMethod == "Hajj_Agency") ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Select Hajj Agency",
                    ),
                    value: int.tryParse(_agencyIdController.text),
                    validator: (val) =>
                        val == null ? "Please select an agency" : null,
                    items: agencies.map<DropdownMenuItem<int>>((agency) {
                      return DropdownMenuItem<int>(
                        value: agency["id"],
                        child: Text(
                            "${agency["name"]} (${agency["license_no"] ?? "N/A"})"),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _agencyIdController.text = val.toString();
                      }
                    },
                  ),
                ],

                /// ============== BEFTN ==============
                if (controller.model.selectedMethod == "BEFTN") ...[
                  TextFormField(
                    controller: _agencyNameController,
                    decoration: const InputDecoration(
                        labelText: "Account Owner Name",
                        border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty
                        ? "This field is required"
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _accountNumberController,
                    decoration: const InputDecoration(
                        labelText: "Account Number",
                        border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty
                        ? "This field is required"
                        : null,
                  ),
                  const SizedBox(height: 8),

                  /// Bank Dropdown
                  FutureBuilder<List<dynamic>>(
                    future: fetchBanks(),
                    builder: (context, bankSnap) {
                      if (bankSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final banks = bankSnap.data ?? [];
                      int? selectedBankId =
                          int.tryParse(_bankNameController.text);
                      return DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: "Bank Name"),
                        value: selectedBankId,
                        validator: (v) =>
                            v == null ? "Please select a bank" : null,
                        items: banks.map<DropdownMenuItem<int>>((bank) {
                          return DropdownMenuItem<int>(
                            value: bank["id"],
                            child: Text(bank["title"]),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _bankNameController.text = val.toString();
                            _districtController.clear();
                            _branchController.clear();
                            setState(() {});
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  if (_bankNameController.text.isNotEmpty)
                    FutureBuilder<List<dynamic>>(
                      future: fetchDistricts(
                          int.parse(_bankNameController.text.trim())),
                      builder: (context, districtSnap) {
                        if (districtSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2));
                        }
                        final districts = districtSnap.data ?? [];
                        int? selectedDistrictId =
                            int.tryParse(_districtController.text);
                        return DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: "District"),
                          value: selectedDistrictId,
                          validator: (v) =>
                              v == null ? "Please select a district" : null,
                          items:
                              districts.map<DropdownMenuItem<int>>((district) {
                            return DropdownMenuItem<int>(
                              value: district["id"],
                              child: Text(district["title"]),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _districtController.text = val.toString();
                              _branchController.clear();
                              setState(() {});
                            }
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 8),

                  if (_bankNameController.text.isNotEmpty &&
                      _districtController.text.isNotEmpty)
                    FutureBuilder<List<dynamic>>(
                      future: fetchBranches(
                        int.parse(_bankNameController.text.trim()),
                        int.parse(_districtController.text.trim()),
                      ),
                      builder: (context, branchSnap) {
                        if (branchSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2));
                        }
                        final branches = branchSnap.data ?? [];
                        int? selectedBranchId =
                            int.tryParse(_branchController.text);
                        return DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: "Branch"),
                          value: selectedBranchId,
                          validator: (v) =>
                              v == null ? "Please select a branch" : null,
                          items: branches.map<DropdownMenuItem<int>>((branch) {
                            return DropdownMenuItem<int>(
                              value: branch["id"],
                              child: Text(branch["title"]),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _branchController.text = val.toString();
                            }
                          },
                        );
                      },
                    ),
                ],

                /// ============== PAY ORDER ==============
                if (controller.model.selectedMethod == "Pay_Order") ...[
                  TextFormField(
                    controller: _payOrderNameController,
                    decoration: const InputDecoration(
                        labelText: "Account Owner Name",
                        border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty
                        ? "This field is required"
                        : null,
                  ),
                ],

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (controller.model.selectedMethod == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Please select a payment method")));
                      return;
                    }

                    if (_formKey.currentState?.validate() ?? false) {
                      final success = await controller.addPaymentInfo(
                        paymentMethod: controller.model.selectedMethod,
                        agencyId: _agencyIdController.text.trim(),
                        agencyName: _agencyNameController.text.trim(),
                        license: _licenseController.text.trim(),
                        accountNo: _accountNumberController.text.trim(),
                        bankId: _bankNameController.text.trim(),
                        districtId: _districtController.text.trim(),
                        branchId: _branchController.text.trim(),
                        payOrderName: _payOrderNameController.text.trim(),
                      );

                      if (success) {
                        _showNotification("Payment info added successfully",
                            success: true);
                        _goToStep(4);
                      } else {
                        _showNotification("Failed to add payment info");
                      }
                    } else {
                      _showNotification("Please fill all required fields");
                    }
                  },
                  child: const Text("Add Payment Info"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _step5Submit(RefundController controller) {
    final model = controller.model;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Review Refund Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (model.pilgrim != null)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Name: ${model.pilgrim?.name ?? ""}"),
                      Text("Tracking No: ${model.pilgrim?.trackingNo ?? ""}"),
                      Text("Phone: ${_phoneController.text.trim()}"),
                      Text("Refund ID: ${model.refundId ?? ""}"),
                      Text("Gender: ${model.pilgrim?.gender}"),
                      Text("Payment Status: ${model.pilgrim?.paymentStatus}"),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              "Payment Info",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (model.selectedMethod != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Payment Method: ${model.selectedMethod}"),
                      const SizedBox(height: 8),
                      if (model.selectedMethod == "Hajj_Agency")
                        Text("Agency ID: ${_agencyIdController.text}"),
                      if (model.selectedMethod == "BEFTN") ...[
                        Text("Account Owner: ${_agencyNameController.text}"),
                        Text("Account No: ${_accountNumberController.text}"),
                        Text("Bank ID: ${_bankNameController.text}"),
                        Text("District ID: ${_districtController.text}"),
                        Text("Branch ID: ${_branchController.text}"),
                      ],
                      if (model.selectedMethod == "Pay_Order")
                        Text("Pay Order Name: ${_payOrderNameController.text}"),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  final success = await controller.submitRefund();
                  if (success) {
                    _showNotification("Refund submitted successfully",
                        success: true);
                    controller.reset();
                    _trackingController.clear();
                    _phoneController.clear();
                    _otpController.clear();
                    _agencyIdController.clear();
                    _agencyNameController.clear();
                    _licenseController.clear();
                    _accountNumberController.clear();
                    _bankNameController.clear();
                    _districtController.clear();
                    _branchController.clear();
                    _payOrderNameController.clear();
                    _goToStep(0);
                  } else {
                    _showNotification("Refund submission failed");
                  }
                },
                child: const Text("Submit Refund"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _methodButton(
      String value, String label, RefundController controller) {
    final isSelected = controller.model.selectedMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          controller.setSelectedMethod(value);
          _agencyIdController.clear();
          _agencyNameController.clear();
          _licenseController.clear();
          _accountNumberController.clear();
          _bankNameController.clear();
          _districtController.clear();
          _branchController.clear();
          _payOrderNameController.clear();
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
