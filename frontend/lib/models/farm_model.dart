class Farm {
  final String id;
  final String name;
  final String owner;
  final String role;
  final String village;
  final String state;
  final double latitude;
  final double longitude;
  final double totalAcres;
  final List<String> primaryCrops;
  final String activeCrop;
  final String sowingDate;
  final String cropStage;
  final double complianceScore;
  final int syncPendingCount;

  Farm({
    required this.id,
    required this.name,
    required this.owner,
    required this.role,
    required this.village,
    required this.state,
    required this.latitude,
    required this.longitude,
    required this.totalAcres,
    required this.primaryCrops,
    required this.activeCrop,
    required this.sowingDate,
    required this.cropStage,
    required this.complianceScore,
    required this.syncPendingCount,
  });

  factory Farm.fromJson(Map<String, dynamic> json) {
    return Farm(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      owner: json['owner'] ?? '',
      role: json['role'] ?? 'FARMER',
      village: json['village'] ?? '',
      state: json['state'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 20.1985,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 73.8322,
      totalAcres: (json['total_acres'] as num?)?.toDouble() ?? 10.0,
      primaryCrops: json['primary_crops'] != null ? List<String>.from(json['primary_crops']) : [],
      activeCrop: json['active_crop'] ?? 'Cotton',
      sowingDate: json['sowing_date'] ?? '2026-06-15',
      cropStage: json['crop_stage'] ?? 'Flowering',
      complianceScore: (json['compliance_score'] as num?)?.toDouble() ?? 95.0,
      syncPendingCount: json['sync_pending_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'owner': owner,
      'role': role,
      'village': village,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'total_acres': totalAcres,
      'primary_crops': primaryCrops,
      'active_crop': activeCrop,
      'sowing_date': sowingDate,
      'crop_stage': cropStage,
      'compliance_score': complianceScore,
      'sync_pending_count': syncPendingCount,
    };
  }
}
