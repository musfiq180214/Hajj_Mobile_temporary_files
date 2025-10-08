import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:labbayk/core/utils/logger.dart';
import 'package:labbayk/core/constants/urls.dart';
import 'package:labbayk/features/auth/providers/login_provider.dart';
import 'package:labbayk/features/pre_registration/domain/pre_reg_list.dart';

/// ----------------- MODEL -----------------
class RefundModel {
  Pilgrim? pilgrim;
  bool otpSent = false;
  bool otpVerified = false;
  String requestKey = "";
  String? selectedMethod;
  int? refundId;

  Map<String, dynamic>? pilgrimData;
  List<dynamic> groupPilgrims = [];
  List<Pilgrim> addedPilgrims = [];

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

  Future<bool> submitRefund(int refundId,
      {Map<String, dynamic>? payload}) async {
    try {
      //AppLogger.i("📤 Submitting Refund ID: $refundId");
      if (payload != null) AppLogger.i("📤 Payload: $payload");

      final response = await _dio.post(
        '/v2/user/refunds/submit',
        data: payload,
        options: Options(validateStatus: (status) => true),
      );

      AppLogger.i(
          "📥 Submit Response [${response.statusCode}]: ${response.data}");
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e("❌ Error submitting refund: $e");
      return false;
    }
  }

  Future<bool> addPaymentInfo(
      int refundId, Map<String, dynamic> payload) async {
    try {
      AppLogger.i("📤 Adding Payment Info for Refund ID: $refundId");
      AppLogger.i("📤 Payload: $payload");

      final response = await _dio.put(
        '/v2/user/refunds/$refundId/add_payment_info/',
        data: payload,
        options: Options(validateStatus: (status) => true),
      );

      AppLogger.i(
          "📥 Add Payment Response [${response.statusCode}]: ${response.data}");
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.e("❌ Error adding payment info: $e");
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

  void setSelectedMethod(String? method) {
    if (method == null) return;
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
      case "hajj_agency":
        payload.addAll({
          'payment_type': 'hajj_agency',
          'agency_id': int.tryParse(agencyId ?? '') ?? 0,
        });
        break;
      case "pay_order":
        payload.addAll({
          'payment_type': 'pay_order',
          'pay_order_name': payOrderName ?? '',
        });
        break;
      case "beftn":
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

  void reset() {
    model.pilgrimData = null;
    model.groupPilgrims.clear();
    model.otpSent = false;
    model.otpVerified = false;
    model.requestKey = "";
    model.selectedMethod = null;
    model.refundId = null;
    selectedTrackingNos.clear();
    notifyListeners();
  }

  final Set<String> selectedTrackingNos = {};

  void togglePilgrimSelection(String trackingNo, bool isSelected) {
    if (isSelected) {
      selectedTrackingNos.add(trackingNo);
    } else {
      selectedTrackingNos.remove(trackingNo);
    }
    notifyListeners();
  }

  bool isPilgrimSelected(String trackingNo) {
    return selectedTrackingNos.contains(trackingNo);
  }

  /// ----------------- HARD-CODED VERIFY OTP -----------------
  Future<bool> verifyOtp(String otp) async {
    if (model.requestKey.isEmpty) return false;

    final response = {
      "data": {
        "pilgrim_info": {
          "id": 64305,
          "tracking_no": "N17F49F3BA",
          "full_name_bangla": "মোঃ মশিউর রহমান",
          "full_name_english": "Md. Moshiur Rahman",
          "birth_date": "1995-11-10",
          "serial_no": 1543,
          "father_name": "null",
          "father_name_english": "null",
          "mobile": "01517816145",
          "group_payment_id": 9197,
          "is_govt": "Government",
          "pre_reg_agency_id": 0,
          "profile_pic":
              "https://prpuat.oss.net.bd/get-image/prp/64305_N17F49F3BA/8c37964c7af5b825394f4137b026b08c9bdbfa73"
        },
        "group_pilgrim_list": [
          {
            "id": 64305,
            "tracking_no": "N17F49F3BA",
            "full_name_bangla": "মোঃ মশিউর রহমান",
            "full_name_english": "Md. Moshiur Rahman",
            "birth_date": "1995-11-10",
            "serial_no": 1543,
            "father_name": "null",
            "father_name_english": "null",
            "mobile": "01517816145",
            "group_payment_id": 9197,
            "is_govt": "Government",
            "pre_reg_agency_id": 0,
            "uid": "64305_N17F49F3BA"
          },
          {
            "id": 64306,
            "tracking_no": "N17F4B7A5E",
            "full_name_bangla": "মোঃ মশিউর রহমান",
            "full_name_english": "Md. Moshiur Rahman",
            "birth_date": "1995-11-10",
            "serial_no": 1544,
            "father_name": "null",
            "father_name_english": "null",
            "mobile": "01517816145",
            "group_payment_id": 9197,
            "is_govt": "Government",
            "pre_reg_agency_id": 0,
            "uid": "64306_N17F4B7A5E"
          }
        ]
      }
    };

    model.pilgrimData =
        response['data']?['pilgrim_info'] as Map<String, dynamic>?;
    model.groupPilgrims =
        (response['data']?['group_pilgrim_list'] as List<dynamic>? ?? []);
    model.refundId = model.pilgrimData?['id'] as int?;

    model.addedPilgrims = model.groupPilgrims
        .map((p) => Pilgrim(
              id: p['id'] as int?,
              trackingNo: p['tracking_no'] as String?,
              name: p['full_name_english'] as String?,
              gender: p['is_govt'] as String?,
              isSelected: false,
            ))
        .toList();

    setOtpVerified(true);
    return true;
  }

  Future<bool> submitRefund({Map<String, dynamic>? paymentData}) async {
    if (model.refundId == null) return false;

    final payload = {
      "refund_id": model.refundId,
      "tracking_nos": selectedTrackingNos.toList(),
      "payment_type": model.selectedMethod,
    };

    if (paymentData != null) {
      switch (model.selectedMethod) {
        case "hajj_agency":
          payload['agency_id'] = paymentData['agency_id'];
          break;
        case "pay_order":
          payload['pay_order_name'] = paymentData['pay_order_name'];
          break;
        case "beftn":
          payload.addAll({
            'beftn_account_name': paymentData['beftn_account_name'],
            'beftn_account_no': paymentData['beftn_account_no'],
            'beftn_bank_id': paymentData['beftn_bank_id'],
            'beftn_district_id': paymentData['beftn_district_id'],
            'beftn_branch_id': paymentData['beftn_branch_id'],
          });
          break;
      }
    }

    AppLogger.i("Submitting Refund with payload: $payload");
    final result =
        await apiClient.submitRefund(model.refundId!, payload: payload);
    AppLogger.i("Submit Refund Result: $result");
    return result;
  }
}

/// ----------------- PROVIDER -----------------
final refundControllerProvider =
    ChangeNotifierProvider((ref) => RefundController(ref));

/// ----------------- UI -----------------
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

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

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
    setState(() => _currentStep = step.clamp(0, 4));
    _pageController.jumpToPage(_currentStep);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(refundControllerProvider);

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
                _step2AddPilgrim(controller),
                _step3PaymentMethod(controller),
                _step4Review(controller),
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
                        child: const Text("Previous")),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                      onPressed: () async {
                        switch (_currentStep) {
                          case 0:
                            if (_trackingController.text.isEmpty ||
                                _phoneController.text.isEmpty) {
                              _showNotification(
                                  "Tracking No and Phone are required");
                              return;
                            }
                            controller.setRequestKey("hardcoded_key_123");
                            controller.setOtpSent(true);
                            _goToStep(1);
                            break;

                          case 1:
                            if (_otpController.text.isEmpty) {
                              _showNotification("OTP is required");
                              return;
                            }
                            final verified =
                                await controller.verifyOtp(_otpController.text);
                            if (verified) _goToStep(2);
                            break;

                          case 2:
                            if (controller.selectedTrackingNos.isEmpty) {
                              _showNotification("Select at least one pilgrim");
                              return;
                            }
                            _goToStep(3);
                            break;

                          case 3:
                            final formValid =
                                (_formKey.currentState?.validate() ?? false) &&
                                    controller.model.selectedMethod != null;

                            if (!formValid) {
                              _showNotification(
                                  "Please select a payment method and fill all required fields");
                              return;
                            }
                            _goToStep(4);
                            break;

                          case 4:
                            // In _currentStep == 4
                            final submitted = await controller.submitRefund(
                              paymentData: {
                                'agency_id':
                                    int.tryParse(_agencyIdController.text),
                                'pay_order_name': _payOrderNameController.text,
                                'beftn_account_name':
                                    _agencyNameController.text,
                                'beftn_account_no':
                                    _accountNumberController.text,
                                'beftn_bank_id':
                                    int.tryParse(_bankNameController.text),
                                'beftn_district_id':
                                    int.tryParse(_districtController.text),
                                'beftn_branch_id':
                                    int.tryParse(_branchController.text),
                              },
                            );

                            if (submitted) {
                              _showNotification("Refund submitted",
                                  success: true);
                              controller.reset();
                              _trackingController.clear();
                              _phoneController.clear();
                              _otpController.clear();
                              _goToStep(0);
                            }
                            break;
                        }
                      },
                      child: Text(_currentStep == 4 ? "Submit" : "Next")),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (i) {
        return CircleAvatar(
          radius: 16,
          backgroundColor: _currentStep >= i ? Colors.green : Colors.grey,
          child: Text(
            "${i + 1}",
            style: const TextStyle(color: Colors.white),
          ),
        );
      }),
    );
  }

  Widget _step0(RefundController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _trackingController,
            decoration: const InputDecoration(labelText: "Tracking No"),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: "Phone"),
          ),
        ],
      ),
    );
  }

  Widget _step1(RefundController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _otpController,
        decoration: const InputDecoration(labelText: "Enter OTP"),
      ),
    );
  }

  Widget _step2AddPilgrim(RefundController controller) {
    final pilgrims = controller.model.groupPilgrims;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text("Select Additional Pilgrims",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: pilgrims.length,
              itemBuilder: (context, index) {
                final p = pilgrims[index];
                final isSelected =
                    controller.selectedTrackingNos.contains(p['tracking_no']);
                return CheckboxListTile(
                  value: isSelected,
                  title: Text(p['full_name_english'] ?? ""),
                  subtitle: Text("Tracking No: ${p['tracking_no']}"),
                  onChanged: (v) {
                    controller.togglePilgrimSelection(
                        p['tracking_no'], v ?? false);
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ],
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

  Widget _step3PaymentMethod(RefundController controller) {
    return Form(
      key: _formKey, // Use the _formKey from the state, not a new one
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
                _methodButton("hajj_agency", "hajj_agency", controller),
                const SizedBox(width: 8),
                _methodButton("beftn", "beftn", controller),
                const SizedBox(width: 8),
                _methodButton("pay_order", "pay_order", controller),
              ],
            ),
            const SizedBox(height: 16),

            if (controller.model.selectedMethod == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text("Please select a payment method",
                    style: TextStyle(color: Colors.red)),
              ),

            /// ----------------- HAJJ AGENCY -----------------
            if (controller.model.selectedMethod == "hajj_agency") ...[
              FutureBuilder<List<dynamic>>(
                future: Dio(BaseOptions(
                  baseUrl: baseUrlDevelopment,
                  headers: {
                    'Authorization': 'Bearer ${ref.read(authTokenProvider)}',
                    'Content-Type': 'application/json',
                  },
                )).get('/v2/user/dropdown/agencies').then((res) => res.data),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const CircularProgressIndicator();
                  final agencies = snapshot.data ?? [];
                  return DropdownButtonFormField<int>(
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
                          "${agency["name"]} (${agency["license_no"] ?? "N/A"})",
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null)
                        _agencyIdController.text = val.toString();
                    },
                  );
                },
              ),
            ],

            /// ----------------- BEFTN -----------------
            if (controller.model.selectedMethod == "beftn") ...[
              TextFormField(
                controller: _agencyNameController,
                decoration: const InputDecoration(
                    labelText: "Account Owner Name",
                    border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.isEmpty ? "This field is required" : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                    labelText: "Account Number", border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.isEmpty ? "This field is required" : null,
              ),
              const SizedBox(height: 8),

              /// Bank Dropdown
              FutureBuilder<List<dynamic>>(
                future: Dio(BaseOptions(
                  baseUrl: baseUrlDevelopment,
                  headers: {
                    'Authorization': 'Bearer ${ref.read(authTokenProvider)}',
                    'Content-Type': 'application/json',
                  },
                )).get('/v2/user/dropdown/banks').then((res) => res.data),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const CircularProgressIndicator();
                  final banks = snapshot.data ?? [];
                  int? selectedBankId = int.tryParse(_bankNameController.text);
                  return SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                          labelText: "Bank", border: OutlineInputBorder()),
                      value: selectedBankId,
                      validator: (v) =>
                          v == null ? "Please select a bank" : null,
                      items: banks.map((bank) {
                        return DropdownMenuItem<int>(
                          value: bank["id"],
                          child: Text(
                            bank["title"],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          _bankNameController.text = val.toString();
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              /// District Dropdown
              FutureBuilder<List<dynamic>>(
                future: Dio(BaseOptions(
                  baseUrl: baseUrlDevelopment,
                  headers: {
                    'Authorization': 'Bearer ${ref.read(authTokenProvider)}',
                    'Content-Type': 'application/json',
                  },
                )).get('/v2/user/dropdown/districts').then((res) => res.data),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const CircularProgressIndicator();
                  final districts = snapshot.data ?? [];
                  int? selectedDistrictId =
                      int.tryParse(_districtController.text);
                  return SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                          labelText: "District", border: OutlineInputBorder()),
                      value: selectedDistrictId,
                      validator: (v) =>
                          v == null ? "Please select a district" : null,
                      items: districts.map((d) {
                        return DropdownMenuItem<int>(
                          value: d["id"],
                          child: Text(
                            d["title"],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          _districtController.text = val.toString();
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              /// Branch Dropdown
              FutureBuilder<List<dynamic>>(
                future: Dio(BaseOptions(
                  baseUrl: baseUrlDevelopment,
                  headers: {
                    'Authorization': 'Bearer ${ref.read(authTokenProvider)}',
                    'Content-Type': 'application/json',
                  },
                ))
                    .get('/v2/user/dropdown/bank_branches')
                    .then((res) => res.data),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final branches = snapshot.data ?? [];
                  int? selectedBranchId = int.tryParse(_branchController.text);
                  return SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                          labelText: "Branch", border: OutlineInputBorder()),
                      value: selectedBranchId,
                      validator: (v) =>
                          v == null ? "Please select a branch" : null,
                      items: branches.map((b) {
                        return DropdownMenuItem<int>(
                          value: b["id"],
                          child: Text(
                            b["title"],
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          _branchController.text = val.toString();
                      },
                    ),
                  );
                },
              ),
            ],

            /// ----------------- PAY ORDER -----------------
            if (controller.model.selectedMethod == "pay_order") ...[
              TextFormField(
                controller: _payOrderNameController,
                decoration: const InputDecoration(
                    labelText: "Account Owner Name",
                    border: OutlineInputBorder()),
                validator: (v) =>
                    v == null || v.isEmpty ? "This field is required" : null,
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _step4Review(RefundController controller) {
    final selectedPilgrims = controller.model.groupPilgrims
        .where((p) => controller.selectedTrackingNos.contains(p['tracking_no']))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Review Refund",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Text("Payment Method: ${controller.model.selectedMethod ?? "-"}"),
          const SizedBox(height: 8),
          const Text("Selected Pilgrims:"),
          ...selectedPilgrims.map(
              (p) => Text("${p['full_name_english']} (${p['tracking_no']})")),
        ],
      ),
    );
  }
}
