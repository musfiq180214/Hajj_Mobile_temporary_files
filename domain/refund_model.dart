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
