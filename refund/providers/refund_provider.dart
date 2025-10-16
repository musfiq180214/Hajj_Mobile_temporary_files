import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:labbayk/core/network/api_client.dart';
import 'package:labbayk/features/refund/data/refund_repositories.dart';

import 'package:labbayk/features/refund/domain/refund_model.dart';
import 'package:labbayk/core/utils/logger.dart';

final refundControllerProvider =
    ChangeNotifierProvider<RefundController>((ref) {
  final apiClient = ref.read(apiClientProvider);
  final repository = RefundRepository(apiClient);
  return RefundController(ref, repository);
});

class RefundController extends ChangeNotifier {
  final Ref ref;
  final RefundRepository repository;
  final RefundModel model = RefundModel();

  RefundController(this.ref, this.repository);

  final Set<String> selectedTrackingNos = {};
  String? initialTrackingNo;

  List<Map<String, dynamic>> hajjAgencies = [];
  List<Map<String, dynamic>> bankList = [];
  List<Map<String, dynamic>> districtList = [];
  List<Map<String, dynamic>> branchList = [];

  Map<String, dynamic>? selectedAgency;
  Map<String, dynamic>? selectedBankItem;
  Map<String, dynamic>? selectedDistrictItem;
  Map<String, dynamic>? selectedBranchItem;

  // ---------------- Core Operations ----------------
  Future<void> sendOtp(String trackingNo, String phone, String forWhat) async {
    try {
      final key = await repository.sendOtp(trackingNo, phone, forWhat);
      model.requestKey = key;
      model.otpSent = true;
    } catch (e) {
      AppLogger.e(e);
    }
    notifyListeners();
  }

  Future<bool> verifyOtp(String otp) async {
    try {
      final res = await repository.verifyOtp(model.requestKey, otp);
      if (res != null) {
        model.pilgrimData = Map<String, dynamic>.from(res['pilgrim_info']);
        model.groupPaymentReference = int.tryParse(
            res['pilgrim_info']['group_payment_id']?.toString() ?? '');
        model.groupPilgrims =
            List<Map<String, dynamic>>.from(res['group_pilgrim_list'] ?? []);
        model.otpVerified = true;
        return true;
      }
    } catch (e) {
      AppLogger.e("Verify OTP error: $e");
    }
    model.otpVerified = false;
    notifyListeners();
    return false;
  }

  Future<bool> submitRefund(
      {Map<String, dynamic>? paymentData, int? agencyId}) async {
    if (model.requestKey.isEmpty || selectedTrackingNos.isEmpty) return false;
    if (model.selectedMethod == null) return false;

    final body = {
      'request_key': model.requestKey,
      'tracking_nos[]': selectedTrackingNos.toList(),
      'agency_id': agencyId,
      'payment_type': model.selectedMethod!,
      if (paymentData != null) ...paymentData,
    };

    final result = await repository.submitRefund(body);
    return result;
  }

  // ---------------- Dropdown Handling ----------------
  Future<void> loadHajjAgencies({String? keywords}) async {
    hajjAgencies = await repository.fetchDropdown(
      'agencies',
      params: keywords != null ? {'keywords': keywords} : null,
    );
    notifyListeners();
  }

  Future<void> loadBanks({String? keywords}) async {
    bankList = await repository.fetchDropdown(
      'banks',
      params: keywords != null ? {'keywords': keywords} : null,
    );
    notifyListeners();
  }

  Future<void> loadDistricts({String? keywords}) async {
    if (selectedBankItem == null) return;
    districtList = await repository.fetchDropdown(
      'bank_districts',
      params: {
        'bank_id': selectedBankItem!['id'],
        if (keywords != null) 'keywords': keywords,
      },
    );
    notifyListeners();
  }

  Future<void> loadBranches({String? keywords}) async {
    if (selectedBankItem == null || selectedDistrictItem == null) return;
    branchList = await repository.fetchDropdown(
      'bank_branches',
      params: {
        'bank_id': selectedBankItem!['id'],
        'district_id': selectedDistrictItem!['id'],
        if (keywords != null) 'keywords': keywords,
      },
    );
    notifyListeners();
  }

  // ---------------- State Management ----------------
  void togglePilgrimSelection(String trackingNo, bool isSelected) {
    if (trackingNo == initialTrackingNo) return;
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

  void setSelectedMethod(String? method) {
    model.selectedMethod = method;
    notifyListeners();
  }

  void setSelectedAgency(Map<String, dynamic>? agency) {
    selectedAgency = agency;
    notifyListeners(); // Important! So UI updates immediately
  }

  Future<void> setSelectedBank(Map<String, dynamic>? bank) async {
    if (selectedBankItem == bank) return;

    selectedBankItem = bank;
    selectedDistrictItem = null;
    selectedBranchItem = null;
    districtList = [];
    branchList = [];

    notifyListeners(); // Updates the UI

    // Automatically load districts if a bank is selected
    if (bank != null) await loadDistricts();
  }

  Future<void> setSelectedDistrict(Map<String, dynamic>? district) async {
    if (selectedDistrictItem == district) return;

    selectedDistrictItem = district;
    selectedBranchItem = null;
    branchList = [];

    notifyListeners(); // Updates the UI

    // Automatically load branches if a district is selected
    if (district != null) await loadBranches();
  }

  void setSelectedBranch(Map<String, dynamic>? branch) {
    selectedBranchItem = branch;
    notifyListeners(); // Update the UI
  }

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

  Future<List<Map<String, dynamic>>> fetchRefundList() async {
    return await repository.fetchRefundList();
  }
}
