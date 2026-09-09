class BuyerPricingData {
  final double baseMandiPricePerQtl;
  final double pramaanVerifiedPremiumPerQtl;
  final double totalRatePerQtl;
  final double totalLotValueInr;
  final String purityGrade;
  final String traceabilitySealUrl;
  final List<String> buyerAdvantages;

  BuyerPricingData({
    required this.baseMandiPricePerQtl,
    required this.pramaanVerifiedPremiumPerQtl,
    required this.totalRatePerQtl,
    required this.totalLotValueInr,
    required this.purityGrade,
    required this.traceabilitySealUrl,
    required this.buyerAdvantages,
  });

  factory BuyerPricingData.fromJson(Map<String, dynamic> json) {
    return BuyerPricingData(
      baseMandiPricePerQtl: (json['base_mandi_price_per_qtl'] as num?)?.toDouble() ?? 7400.0,
      pramaanVerifiedPremiumPerQtl: (json['pramaan_verified_premium_per_qtl'] as num?)?.toDouble() ?? 450.0,
      totalRatePerQtl: (json['total_rate_per_qtl'] as num?)?.toDouble() ?? 7850.0,
      totalLotValueInr: (json['total_lot_value_inr'] as num?)?.toDouble() ?? 785000.0,
      purityGrade: json['purity_grade'] ?? 'Grade A+',
      traceabilitySealUrl: json['traceability_seal_url'] ?? '',
      buyerAdvantages: json['buyer_advantages'] != null ? List<String>.from(json['buyer_advantages']) : [],
    );
  }
}
