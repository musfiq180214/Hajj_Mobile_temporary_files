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
      AppLogger.i("Sending OTP to $phone for tracking no $trackingNo");

      final response = await _dio.post(
        '/v2/user/refunds/get_otp',
        data: {
          'tracking_no': trackingNo,
          'phone': phone,
          'for': 'pre_registration'
        },
        options: Options(validateStatus: (status) => true),
      );

      AppLogger.i("Status: ${response.statusCode}, Data: ${response.data}");

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
      AppLogger.i("Verifying OTP: $otp with requestKey: $requestKey");

      final response = await _dio.post(
        '/v2/user/refunds/verify_otp',
        data: {
          'request_key': requestKey,
          'otp': otp,
        },
        options: Options(validateStatus: (status) => true),
      );

      AppLogger.i("Status: ${response.statusCode}, Data: ${response.data}");

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data;
        return data['id'] != null ? int.tryParse(data['id'].toString()) : null;
      }

      return null;
    } catch (e) {
      AppLogger.e("❌ Error verifying OTP: $e");
      return null;
    }
  }

  Future<bool> submitRefund(
      Pilgrim pilgrim, Map<String, dynamic> payload) async {
    try {
      // PUT add_payment_info
      final putResponse = await _dio.put(
        '/v2/user/refunds/${pilgrim.id}/add_payment_info/',
        data: payload,
        options: Options(validateStatus: (status) => true),
      );

      if (putResponse.statusCode != 200) {
        AppLogger.e("Failed to add payment info: ${putResponse.data}");
        return false;
      }

      // POST submit
      final submitResponse =
          await _dio.post('/v2/user/refunds/${pilgrim.id}/submit');

      AppLogger.i("Refund submission status: ${submitResponse.statusCode}");
      return submitResponse.statusCode == 200;
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

  void setPilgrim(Pilgrim pilgrim) {
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

  Future<bool> submitRefund({
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
    if (model.pilgrim == null) return false;

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

    return await apiClient.submitRefund(model.pilgrim!, payload);
  }
}

/// ----------------- PROVIDER -----------------
final refundControllerProvider =
    ChangeNotifierProvider((ref) => RefundController(ref));

/// ----------------- VIEW -----------------
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
    final controller = ref.watch(refundControllerProvider.notifier);
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
                _step3(controller),
                _step4(controller),
              ],
            ),
          ),
          Row(
            children: [
              if (_currentStep > 0)
                Expanded(
                  child: OutlinedButton(
                      onPressed: () => _goToStep(_currentStep - 1),
                      child: const Text("Back")),
                ),
              if (_currentStep > 0) const SizedBox(width: 8),
              Expanded(
                  child: ElevatedButton(
                      onPressed: () async {
                        if (_currentStep == 0) {
                          if (_trackingController.text.trim().isEmpty) return;
                          _goToStep(1);
                        } else if (_currentStep == 1) {
                          if (!model.otpSent) {
                            final success = await controller.sendOtp(
                                _trackingController.text.trim(),
                                _phoneController.text.trim());
                            if (success) {
                              _showNotification("OTP sent", success: true);
                              setState(() {});
                            } else {
                              _showNotification("Failed to send OTP");
                            }
                          } else if (model.otpSent && !model.otpVerified) {
                            final success = await controller
                                .verifyOtp(_otpController.text.trim());
                            if (success) {
                              _showNotification("OTP verified", success: true);
                              _goToStep(2);
                            } else {
                              _showNotification("Invalid OTP");
                            }
                          }
                        } else if (_currentStep == 2) {
                          _goToStep(3);
                        } else if (_currentStep == 3) {
                          if (model.selectedMethod == null) {
                            _showNotification("Select payment method");
                            return;
                          }

                          final success = await controller.submitRefund(
                            paymentMethod: model.selectedMethod,
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
                        } else {
                          _goToStep(_currentStep + 1);
                        }
                      },
                      child: Text(_currentStep == 0
                          ? "Next"
                          : (_currentStep == 1 && !model.otpSent
                              ? "Send OTP"
                              : (_currentStep == 1 &&
                                      model.otpSent &&
                                      !model.otpVerified
                                  ? "Verify OTP"
                                  : (_currentStep == 3
                                      ? "Submit"
                                      : "Next")))))),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    final steps = ['1', '2', '3', '4', '5'];
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
        ],
      ),
    );
  }

  Widget _step2(RefundController controller) {
    return Center(
      child: Text(
        "OTP Verified! Proceed to payment info.",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _step3(RefundController controller) {
    return SingleChildScrollView(
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
              _methodButton("BEFTN", "BEFTN", controller),
              _methodButton("Pay_Order", "Pay Order", controller),
            ],
          ),
          const SizedBox(height: 16),
          if (controller.model.selectedMethod == "Hajj_Agency") ...[
            TextFormField(
              controller: _agencyIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Agency ID", border: OutlineInputBorder()),
            ),
          ],
          if (controller.model.selectedMethod == "BEFTN") ...[
            TextFormField(
              controller: _agencyNameController,
              decoration: const InputDecoration(
                  labelText: "Account Owner", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _accountNumberController,
              decoration: const InputDecoration(
                  labelText: "Account No", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bankNameController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Bank ID", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _districtController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "District ID", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _branchController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Branch ID", border: OutlineInputBorder()),
            ),
          ],
          if (controller.model.selectedMethod == "Pay_Order") ...[
            TextFormField(
              controller: _payOrderNameController,
              decoration: const InputDecoration(
                  labelText: "Pay Order Name", border: OutlineInputBorder()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _step4(RefundController controller) {
    return Center(
      child: Text(
        "Review your payment info and click Submit",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
