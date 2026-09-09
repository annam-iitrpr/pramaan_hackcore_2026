import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/evidence_model.dart';
import 'package:frontend/models/farm_model.dart';
import 'package:frontend/models/product_model.dart';

void main() {
  test('EvidenceItem and GeoLocation serialization test', () {
    final loc = GeoLocation(
      latitude: 20.1985,
      longitude: 73.8322,
      fieldName: 'Plot North-04',
      village: 'Dindori, Nashik',
    );
    expect(loc.latitude, 20.1985);
    expect(loc.fieldName, 'Plot North-04');

    final item = EvidenceItem(
      id: 'EV-TEST-100',
      farmId: 'farm-101',
      cropName: 'Cotton (Bt-II)',
      cropStage: 'Flowering',
      evidenceType: 'VOICE_LOG',
      timestamp: '2026-08-30T10:00:00Z',
      location: loc,
      title: 'Voice Spray Log',
      description: 'Sprayed Bio-Neem 400ml/Acre',
      verificationStatus: 'VERIFIED',
      verificationScore: 97.5,
    );

    final json = item.toJson();
    expect(json['id'], 'EV-TEST-100');
    expect(json['verification_status'], 'VERIFIED');
    expect(json['verification_score'], 97.5);

    final fromJson = EvidenceItem.fromJson(json);
    expect(fromJson.id, 'EV-TEST-100');
    expect(fromJson.cropName, 'Cotton (Bt-II)');
  });

  test('Farm and ProductInput model test', () {
    final farm = Farm(
      id: 'farm-101',
      name: 'Sahyadri Bio-Farms',
      owner: 'Ramesh Patil',
      role: 'FARMER',
      village: 'Dindori',
      state: 'Maharashtra',
      latitude: 20.1985,
      longitude: 73.8322,
      totalAcres: 12.5,
      primaryCrops: ['Cotton', 'Grapes'],
      activeCrop: 'Cotton',
      sowingDate: '2026-06-15',
      cropStage: 'Flowering',
      complianceScore: 96.4,
      syncPendingCount: 0,
    );

    expect(farm.totalAcres, 12.5);
    expect(farm.complianceScore, 96.4);

    final prod = ProductInput(
      qrCode: 'PRM-INP-88219-NEEM',
      barcode: '8901234567890',
      name: 'Bio-Neem Power',
      manufacturer: 'Kisan BioTech Ltd',
      activeIngredient: 'Azadirachtin 1.0% EC',
      category: 'Organic Bio-Pesticide',
      recommendedDose: '400 ml/Acre',
      targetPests: ['Whitefly'],
      preHarvestIntervalDays: 1,
      toxicityBand: 'Green',
      verifiedBatchNo: 'BNP-2026-01',
      expiryDate: '2028-05-15',
      genuineVerified: true,
    );

    expect(prod.genuineVerified, true);
    expect(prod.preHarvestIntervalDays, 1);
  });
}
