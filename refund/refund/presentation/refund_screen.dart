import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labbayk/core/theme/colors.dart';
import 'package:labbayk/features/refund/providers/refund_provider.dart';

class RefundScreen extends ConsumerStatefulWidget {
  const RefundScreen({super.key});

  @override
  ConsumerState<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends ConsumerState<RefundScreen> {
  final PageController _pageController = PageController();
  int _currentStep = -1;

  // Inputs
  final _trackingController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _payOrderNameController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _trackingController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
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
    setState(() => _currentStep = step.clamp(-1, 4));
    if (step >= 0 && step <= 4) {
      _pageController.jumpToPage(step);
    }
    if (step == 3) {
      // preload dropdowns
      final controller = ref.read(refundControllerProvider);
      Future.wait([
        controller.loadBanks(),
        controller.loadHajjAgencies(),
      ]);
    }
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

  int _getStepFromStatus(String? status) {
    switch (status) {
      case 'otp_verified':
        return 2;
      case 'otp_sent':
        return 1;
      case 'pending':
      default:
        return 0;
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
                    child: _buildStepper()),
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
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              textStyle: const TextStyle(fontSize: 15),
                            ),
                            onPressed: () async {
                              final ctrl = ref.read(refundControllerProvider);
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
                                    const forWhat = "pre_registration";
                                    await ctrl.sendOtp(
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
                                    final verified = await ctrl
                                        .verifyOtp(_otpController.text.trim());
                                    if (verified) {
                                      _showNotification("OTP verified",
                                          success: true);
                                      final tracking =
                                          _trackingController.text.trim();
                                      ctrl.initialTrackingNo = tracking;
                                      ctrl.selectedTrackingNos.add(tracking);
                                      _goToStep(2);
                                    } else {
                                      _showNotification(
                                          "OTP verification failed");
                                    }
                                  } catch (e) {
                                    _showNotification(
                                        "Error verifying OTP: $e");
                                  }
                                  break;

                                case 2:
                                  if (ctrl.selectedTrackingNos.isEmpty) {
                                    _showNotification(
                                        "Select at least one pilgrim");
                                    return;
                                  }
                                  _goToStep(3);
                                  break;

                                case 3:
                                  if (!_validatePaymentStep(ctrl)) {
                                    _showNotification(
                                        "Please fill all required fields for the selected payment method");
                                    return;
                                  }
                                  _goToStep(4);
                                  break;

                                case 4:
                                  if (!_validatePaymentStep(ctrl)) {
                                    _showNotification(
                                        "Please fill all required fields for the selected payment method");
                                    return;
                                  }

                                  final agencyId = ctrl.selectedAgency != null
                                      ? int.tryParse(
                                          ctrl.selectedAgency!['id'].toString())
                                      : null;

                                  Map<String, dynamic>? paymentData;
                                  switch (ctrl.model.selectedMethod) {
                                    case 'beftn':
                                      paymentData = {
                                        'beftn_account_name':
                                            _accountNameController.text.trim(),
                                        'beftn_account_no':
                                            _accountNumberController.text
                                                .trim(),
                                        'beftn_bank_id':
                                            ctrl.selectedBankItem?['id'] ?? 0,
                                        'beftn_district_id':
                                            ctrl.selectedDistrictItem?['id'] ??
                                                0,
                                        'beftn_branch_id':
                                            ctrl.selectedBranchItem?['id'] ?? 0,
                                      };
                                      break;
                                    case 'pay_order':
                                      paymentData = {
                                        'pay_order_name':
                                            _payOrderNameController.text.trim()
                                      };
                                      break;
                                    case 'hajj_agency':
                                      paymentData = {};
                                      break;
                                  }

                                  try {
                                    final success = await ctrl.submitRefund(
                                        paymentData: paymentData,
                                        agencyId: agencyId);
                                    if (success) {
                                      _showNotification(
                                          "Refund submitted successfully",
                                          success: true);
                                      ctrl.reset();
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
        if (i.isEven) {
          final stepIndex = i ~/ 2;
          final isActive = stepIndex <= _currentStep;
          return CircleAvatar(
            radius: 14,
            backgroundColor: isActive ? primaryColor : grey,
            child: Text("${stepIndex + 1}",
                style: const TextStyle(color: textColorPrimary, fontSize: 12)),
          );
        } else {
          final lineIndex = (i - 1) ~/ 2;
          final isLineActive = lineIndex < _currentStep;
          return Expanded(
              child: Container(
                  height: 3, color: isLineActive ? primaryColor : grey));
        }
      }),
    );
  }

  Widget _stepRefundList(RefundController controller) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: controller.fetchRefundList(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];

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
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 24),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed: () {
                    controller.reset();
                    _goToStep(0);
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
                      refund['status']?.toString().toUpperCase() ?? 'PENDING';
                  return ListTile(
                    title: Text("Tracking: ${refund['tracking_no']}"),
                    subtitle: Text("Status: $status"),
                    trailing: ElevatedButton(
                      onPressed: () {
                        final step =
                            _getStepFromStatus(refund['status']?.toString());
                        _goToStep(step);

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
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text("Enter OTP",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColorPrimary)),
        const SizedBox(height: 8),
        const Text("We’ve sent a 6-digit OTP to your phone number.",
            textAlign: TextAlign.center,
            style: TextStyle(color: textColorSecondary)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 45,
              child: TextField(
                maxLength: 1,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    counterText: "",
                    enabledBorder: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder()),
                onChanged: (val) {
                  if (val.isNotEmpty && index < 5)
                    FocusScope.of(context).nextFocus();
                  if (val.isEmpty && index > 0)
                    FocusScope.of(context).previousFocus();

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
        TextButton.icon(
          icon: const Icon(Icons.refresh, color: primaryColor),
          label: const Text("Resend OTP",
              style: TextStyle(
                  color: textColorPrimary, fontWeight: FontWeight.bold)),
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
      ]),
    );
  }

  Widget _step2AddPilgrim(RefundController controller) {
    final pilgrims = controller.model.groupPilgrims;
    if (pilgrims.isEmpty) {
      return const Center(
          child: Text("No pilgrims found",
              style: TextStyle(color: textColorPrimary)));
    }

    return ListView.builder(
      itemCount: pilgrims.length,
      itemBuilder: (context, index) {
        final pilgrim = pilgrims[index];
        final tracking = pilgrim['tracking_no'] ?? '';
        final name = pilgrim['full_name_english'] ??
            pilgrim['full_name_bangla'] ??
            'Unknown';
        final isInitial = tracking == controller.initialTrackingNo;
        final isSelected = controller.isPilgrimSelected(tracking);

        return CheckboxListTile(
          title: Text(name,
              style: TextStyle(
                  color: isInitial ? textColorPrimary : textColorSecondary,
                  fontWeight: isInitial ? FontWeight.bold : FontWeight.normal)),
          value: isSelected,
          onChanged: isInitial
              ? null
              : (v) => controller.togglePilgrimSelection(tracking, v ?? false),
        );
      },
    );
  }

  Widget _step3PaymentMethod(RefundController controller) {
    Widget agencyDropdown() {
      if (controller.hajjAgencies.isEmpty) {
        return const CircularProgressIndicator();
      }
      return DropdownButtonFormField<int>(
        value: controller.selectedAgency != null
            ? int.tryParse(controller.selectedAgency!['id'].toString())
            : null,
        hint: const Text("Select Agency",
            style: TextStyle(color: textColorPrimary)),
        isExpanded: true,
        decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
        items: controller.hajjAgencies.map((a) {
          return DropdownMenuItem<int>(
              value: int.tryParse(a['id'].toString()),
              child: Text(a['name'] ?? ''));
        }).toList(),
        onChanged: (val) {
          if (val == null) return;
          final agency = controller.hajjAgencies
              .firstWhere((a) => int.tryParse(a['id'].toString()) == val);
          controller.setSelectedAgency(agency);
        },
      );
    }

    Widget bankDropdown() {
      final isEnabled = controller.selectedAgency != null;
      return DropdownButtonFormField<int>(
        value: controller.selectedBankItem != null
            ? controller.selectedBankItem!['id'] as int
            : null,
        hint: Text("Select Bank",
            style:
                TextStyle(color: isEnabled ? textColorPrimary : Colors.grey)),
        isExpanded: true,
        decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
        items: isEnabled
            ? controller.bankList
                .map((b) => DropdownMenuItem<int>(
                    value: b['id'] as int, child: Text(b['title'] ?? '')))
                .toList()
            : [],
        onChanged: isEnabled
            ? (val) async {
                if (val == null) return;
                final bank =
                    controller.bankList.firstWhere((b) => b['id'] == val);
                await controller.setSelectedBank(bank);
              }
            : null,
      );
    }

    Widget districtDropdown() {
      final isEnabled = controller.selectedBankItem != null;
      return DropdownButtonFormField<int>(
        value: controller.selectedDistrictItem != null
            ? controller.selectedDistrictItem!['id'] as int
            : null,
        hint: Text("Select District",
            style:
                TextStyle(color: isEnabled ? textColorPrimary : Colors.grey)),
        isExpanded: true,
        decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
        items: isEnabled
            ? controller.districtList
                .map((d) => DropdownMenuItem<int>(
                    value: d['id'] as int, child: Text(d['title'] ?? '')))
                .toList()
            : [],
        onChanged: isEnabled
            ? (val) async {
                if (val == null) return;
                final district =
                    controller.districtList.firstWhere((d) => d['id'] == val);
                await controller.setSelectedDistrict(district);
              }
            : null,
      );
    }

    Widget branchDropdown() {
      final isEnabled = controller.selectedDistrictItem != null;
      return DropdownButtonFormField<int>(
        value: controller.selectedBranchItem != null
            ? controller.selectedBranchItem!['id'] as int
            : null,
        hint: Text("Select Branch",
            style:
                TextStyle(color: isEnabled ? textColorPrimary : Colors.grey)),
        isExpanded: true,
        decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
        items: isEnabled
            ? controller.branchList
                .map((b) => DropdownMenuItem<int>(
                    value: b['id'] as int, child: Text(b['title'] ?? '')))
                .toList()
            : [],
        onChanged: isEnabled
            ? (val) {
                if (val == null) return;
                final branch =
                    controller.branchList.firstWhere((b) => b['id'] == val);
                controller.setSelectedBranch(branch);
              }
            : null,
      );
    }

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
          final isDisabled = entry.key != 'beftn'; // Only BEFTN enabled
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? primaryColor
                      : isDisabled
                          ? grey
                          : grey2,
                  foregroundColor: isDisabled
                      ? grey
                      : isSelected
                          ? Colors.white
                          : Colors.black87,
                ),
                onPressed: isDisabled
                    ? null
                    : () => controller.setSelectedMethod(entry.key),
                child: Text(entry.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          );
        }).toList(),
      );
    }

    Widget paymentForm() {
      final selected = controller.model.selectedMethod;
      if (selected == null) return const SizedBox();
      if (selected == 'pay_order' || selected == 'hajj_agency') {
        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: grey)),
          child: const Row(
            children: [
              Icon(Icons.lock, color: primaryColor),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      "This payment method is currently unavailable. Please use Bank Transfer (BEFTN).",
                      style: TextStyle(fontSize: 13, color: textColorPrimary))),
            ],
          ),
        );
      }

      // BEFTN form
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          agencyDropdown(),
          const SizedBox(height: 12),
          TextField(
              controller: _accountNameController,
              decoration: const InputDecoration(labelText: "Account Name")),
          TextField(
              controller: _accountNumberController,
              decoration: const InputDecoration(labelText: "Account Number")),
          const SizedBox(height: 12),
          bankDropdown(),
          const SizedBox(height: 8),
          districtDropdown(),
          const SizedBox(height: 8),
          branchDropdown(),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Select Payment Method",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColorPrimary)),
        const SizedBox(height: 12),
        paymentTypeSelector(),
        const SizedBox(height: 16),
        paymentForm(),
      ]),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Selected Method: ${controller.model.selectedMethod ?? '-'}",
            style: TextStyle(color: textColorPrimary)),
        const SizedBox(height: 8),
        Text("Selected Pilgrims: ${controller.selectedTrackingNos.join(', ')}",
            style: TextStyle(color: textColorPrimary)),
        const SizedBox(height: 16),
        const Text("Payment Details:",
            style: TextStyle(
                fontWeight: FontWeight.bold, color: textColorPrimary)),
        ...paymentDataPreview.entries.map((e) => Text("${e.key}: ${e.value}")),
      ]),
    );
  }
}
