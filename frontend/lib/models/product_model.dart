class ProductInput {
  final String qrCode;
  final String barcode;
  final String name;
  final String manufacturer;
  final String activeIngredient;
  final String category;
  final String recommendedDose;
  final List<String> targetPests;
  final int preHarvestIntervalDays;
  final String toxicityBand;
  final String verifiedBatchNo;
  final String expiryDate;
  final bool genuineVerified;

  ProductInput({
    required this.qrCode,
    required this.barcode,
    required this.name,
    required this.manufacturer,
    required this.activeIngredient,
    required this.category,
    required this.recommendedDose,
    required this.targetPests,
    required this.preHarvestIntervalDays,
    required this.toxicityBand,
    required this.verifiedBatchNo,
    required this.expiryDate,
    required this.genuineVerified,
  });

  factory ProductInput.fromJson(Map<String, dynamic> json) {
    return ProductInput(
      qrCode: json['qr_code'] ?? '',
      barcode: json['barcode'] ?? '',
      name: json['name'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      activeIngredient: json['active_ingredient'] ?? '',
      category: json['category'] ?? '',
      recommendedDose: json['recommended_dose'] ?? '',
      targetPests: json['target_pests'] != null ? List<String>.from(json['target_pests']) : [],
      preHarvestIntervalDays: json['pre_harvest_interval_days'] ?? 0,
      toxicityBand: json['toxicity_band'] ?? 'Green',
      verifiedBatchNo: json['verified_batch_no'] ?? '',
      expiryDate: json['expiry_date'] ?? '',
      genuineVerified: json['genuine_verified'] ?? true,
    );
  }
}
