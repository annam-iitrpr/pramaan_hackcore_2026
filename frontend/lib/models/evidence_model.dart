class EvidenceItem {
  final String id;
  final String farmId;
  final String cropName;
  final String cropStage;
  final String evidenceType;
  final String timestamp;
  final GeoLocation location;
  final WeatherSnapshot? weather;
  final String title;
  final String description;
  final String? mediaUrl;
  final String? audioTranscript;
  final String? productQr;
  final String? productName;
  final String? dosagePerAcre;
  final String? farmerName;
  final String? farmerPhone;
  String verificationStatus;
  double verificationScore;
  final String? verificationHash;
  final Map<String, dynamic> agentVerdicts;
  final List<String> flagReasons;
  final double completenessScore;
  final String consistencyStatus;
  final String validationStatus;
  final String requiredAction;
  final List<Map<String, dynamic>> flags;

  EvidenceItem({
    required this.id,
    required this.farmId,
    required this.cropName,
    required this.cropStage,
    required this.evidenceType,
    required this.timestamp,
    required this.location,
    this.weather,
    required this.title,
    required this.description,
    this.mediaUrl,
    this.audioTranscript,
    this.productQr,
    this.productName,
    this.dosagePerAcre,
    this.farmerName,
    this.farmerPhone,
    required this.verificationStatus,
    required this.verificationScore,
    this.verificationHash,
    this.agentVerdicts = const {},
    this.flagReasons = const [],
    this.completenessScore = 0.95,
    this.consistencyStatus = 'consistent',
    this.validationStatus = 'validated',
    this.requiredAction = 'none',
    this.flags = const [],
  });

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    final rawCrop = json['crop_name']?.toString() ?? json['crop']?.toString() ?? 'Crop';
    final rawDesc = json['description']?.toString() ?? json['voice_transcript']?.toString() ?? json['title']?.toString() ?? '';
    final rawTitle = json['title']?.toString() ??
        (json['action_type'] != null ? "Voice Log: ${json['action_type']} $rawCrop" : "Field Observation: $rawCrop");
    final rawVillage = json['village']?.toString() ??
        (json['location'] is Map ? json['location']['village']?.toString() : null) ??
        'Nashik';

    // Parse flags list
    List<Map<String, dynamic>> parsedFlags = [];
    if (json['flags'] is List) {
      for (var f in json['flags']) {
        if (f is Map) {
          parsedFlags.add(Map<String, dynamic>.from(f));
        }
      }
    }

    return EvidenceItem(
      id: json['id']?.toString() ?? json['log_id']?.toString() ?? 'EV-${DateTime.now().millisecondsSinceEpoch}',
      farmId: json['farm_id']?.toString() ?? 'farm-101',
      cropName: rawCrop,
      cropStage: json['crop_stage']?.toString() ?? 'Active Stage',
      evidenceType: json['evidence_type']?.toString() ?? (json['voice_transcript'] != null ? 'VOICE_LOG' : 'FIELD_OBSERVATION'),
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      location: json['location'] is Map
          ? GeoLocation.fromJson(json['location'])
          : GeoLocation(
              latitude: 20.1985,
              longitude: 73.8322,
              fieldName: json['plot_name']?.toString() ?? 'Plot North-04',
              village: rawVillage,
            ),
      weather: json['weather'] != null ? WeatherSnapshot.fromJson(json['weather']) : null,
      title: rawTitle,
      description: rawDesc,
      mediaUrl: json['media_url']?.toString(),
      audioTranscript: json['audio_transcript']?.toString() ?? json['voice_transcript']?.toString(),
      productQr: json['product_qr']?.toString(),
      productName: json['product_name']?.toString(),
      dosagePerAcre: json['dosage_per_acre']?.toString() ?? json['dosage']?.toString(),
      farmerName: json['farmer_name']?.toString(),
      farmerPhone: json['farmer_phone']?.toString(),
      verificationStatus: json['verification_status']?.toString() ?? (json['validation_status'] == 'needs_review' ? 'PENDING' : 'VERIFIED'),
      verificationScore: (json['composite_trust_score'] ?? json['verification_score'] ?? json['compliance_score'] as num?)?.toDouble() ?? 98.6,
      verificationHash: json['cryptographic_hash']?.toString() ?? json['verification_hash']?.toString() ?? json['hash_anchor']?.toString(),
      agentVerdicts: json['agent_verdicts'] != null ? Map<String, dynamic>.from(json['agent_verdicts']) : {},
      flagReasons: json['flag_reasons'] != null ? List<String>.from(json['flag_reasons']) : (json['anomalies'] != null ? List<String>.from(json['anomalies']) : []),
      completenessScore: (json['completeness_score'] as num?)?.toDouble() ?? 0.95,
      consistencyStatus: json['consistency_status']?.toString() ?? 'consistent',
      validationStatus: json['validation_status']?.toString() ?? 'validated',
      requiredAction: json['required_action']?.toString() ?? 'none',
      flags: parsedFlags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farm_id': farmId,
      'crop_name': cropName,
      'crop_stage': cropStage,
      'evidence_type': evidenceType,
      'timestamp': timestamp,
      'location': location.toJson(),
      if (weather != null) 'weather': weather!.toJson(),
      'title': title,
      'description': description,
      'media_url': mediaUrl,
      'audio_transcript': audioTranscript,
      'product_qr': productQr,
      'product_name': productName,
      'dosage_per_acre': dosagePerAcre,
      if (farmerName != null) 'farmer_name': farmerName,
      if (farmerPhone != null) 'farmer_phone': farmerPhone,
      'verification_status': verificationStatus,
      'verification_score': verificationScore,
      'verification_hash': verificationHash,
      'agent_verdicts': agentVerdicts,
      'flag_reasons': flagReasons,
    };
  }
}

class GeoLocation {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String fieldName;
  final String village;

  GeoLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters = 5.0,
    this.fieldName = 'Plot North-04',
    this.village = 'Nashik',
  });

  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return GeoLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 20.1985,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 73.8322,
      accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble() ?? 5.0,
      fieldName: json['field_name'] ?? 'Plot North-04',
      village: json['village'] ?? 'Nashik',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_meters': accuracyMeters,
      'field_name': fieldName,
      'village': village,
    };
  }
}

class WeatherSnapshot {
  final double temperatureC;
  final double humidityPercent;
  final double windSpeedKmh;
  final double precipitationProb;
  final String condition;
  final double spraySuitabilityScore;
  final String sprayRecommendation;
  final double? apparentTempC;
  final double? deltaTC;
  final double? dewPointC;
  final double? windGustsKmh;
  final double? cloudCoverPercent;
  final double? soilMoisturePercent;
  final String locationName;
  final String districtName;
  final String stateName;
  final bool isPunjabRegion;
  final String? pauAdvisoryText;

  WeatherSnapshot({
    required this.temperatureC,
    required this.humidityPercent,
    required this.windSpeedKmh,
    required this.precipitationProb,
    required this.condition,
    required this.spraySuitabilityScore,
    required this.sprayRecommendation,
    this.apparentTempC,
    this.deltaTC,
    this.dewPointC,
    this.windGustsKmh,
    this.cloudCoverPercent,
    this.soilMoisturePercent,
    this.locationName = "Ludhiana (ਲੁਧਿਆਣਾ)",
    this.districtName = "Ludhiana",
    this.stateName = "Punjab",
    this.isPunjabRegion = true,
    this.pauAdvisoryText,
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 28.5,
      humidityPercent: (json['humidity_percent'] as num?)?.toDouble() ?? 65.0,
      windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble() ?? 6.0,
      precipitationProb: (json['precipitation_prob'] as num?)?.toDouble() ?? 10.0,
      condition: json['condition'] ?? 'Clear Sunny Skies',
      spraySuitabilityScore: (json['spray_suitability_score'] as num?)?.toDouble() ?? 0.95,
      sprayRecommendation: json['spray_recommendation'] ?? 'Prime spraying conditions.',
      apparentTempC: (json['apparent_temp_c'] as num?)?.toDouble(),
      deltaTC: (json['delta_t_c'] as num?)?.toDouble() ?? 3.5,
      dewPointC: (json['dew_point_c'] as num?)?.toDouble(),
      windGustsKmh: (json['wind_gusts_kmh'] as num?)?.toDouble(),
      cloudCoverPercent: (json['cloud_cover_percent'] as num?)?.toDouble(),
      soilMoisturePercent: (json['soil_moisture_percent'] as num?)?.toDouble(),
      locationName: json['location_name'] ?? 'Ludhiana, Punjab',
      districtName: json['district_name'] ?? 'Ludhiana',
      stateName: json['state_name'] ?? 'Punjab',
      isPunjabRegion: json['is_punjab_region'] ?? true,
      pauAdvisoryText: json['pau_advisory_text'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature_c': temperatureC,
      'humidity_percent': humidityPercent,
      'wind_speed_kmh': windSpeedKmh,
      'precipitation_prob': precipitationProb,
      'condition': condition,
      'spray_suitability_score': spraySuitabilityScore,
      'spray_recommendation': sprayRecommendation,
      'apparent_temp_c': apparentTempC,
      'delta_t_c': deltaTC,
      'dew_point_c': dewPointC,
      'wind_gusts_kmh': windGustsKmh,
      'cloud_cover_percent': cloudCoverPercent,
      'soil_moisture_percent': soilMoisturePercent,
      'location_name': locationName,
      'district_name': districtName,
      'state_name': stateName,
      'is_punjab_region': isPunjabRegion,
      'pau_advisory_text': pauAdvisoryText,
    };
  }
}

