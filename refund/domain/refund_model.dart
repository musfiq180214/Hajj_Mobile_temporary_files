class RefundModel {
  String? selectedMethod;
  bool otpSent;
  bool otpVerified;
  String requestKey;
  Map<String, dynamic>? pilgrimData;
  int? groupPaymentReference;
  List<Map<String, dynamic>> groupPilgrims;

  RefundModel({
    this.selectedMethod,
    this.otpSent = false,
    this.otpVerified = false,
    this.requestKey = "",
    this.pilgrimData,
    this.groupPaymentReference,
    List<Map<String, dynamic>>? groupPilgrims,
  }) : groupPilgrims = groupPilgrims ?? [];

  RefundModel.fromJson(Map<String, dynamic> json)
      : selectedMethod = json['selected_method'] as String?,
        otpSent = json['otp_sent'] as bool? ?? false,
        otpVerified = json['otp_verified'] as bool? ?? false,
        requestKey = json['request_key'] as String? ?? '',
        pilgrimData = json['pilgrim_data'] != null
            ? Map<String, dynamic>.from(json['pilgrim_data'])
            : null,
        groupPaymentReference = json['group_payment_reference'] is int
            ? json['group_payment_reference'] as int
            : (int.tryParse(
                    json['group_payment_reference']?.toString() ?? '') ??
                null),
        groupPilgrims = json['group_pilgrims'] is List
            ? List<Map<String, dynamic>>.from(json['group_pilgrims'])
            : [];

  Map<String, dynamic> toJson() {
    return {
      'selected_method': selectedMethod,
      'otp_sent': otpSent,
      'otp_verified': otpVerified,
      'request_key': requestKey,
      'pilgrim_data': pilgrimData,
      'group_payment_reference': groupPaymentReference,
      'group_pilgrims': groupPilgrims,
    };
  }
}
