import 'evidence_model.dart';
export 'evidence_model.dart';


class SprayWindowSlot {
  final String timeWindow;
  final String suitability; // OPTIMAL, MODERATE, DO_NOT_SPRAY
  final double temperatureC;
  final double windKmh;
  final int rainProbabilityPercent;
  final String advisoryReason;
  final double? deltaTC;
  final double? humidityPercent;

  SprayWindowSlot({
    required this.timeWindow,
    required this.suitability,
    required this.temperatureC,
    required this.windKmh,
    required this.rainProbabilityPercent,
    required this.advisoryReason,
    this.deltaTC,
    this.humidityPercent,
  });

  factory SprayWindowSlot.fromJson(Map<String, dynamic> json) {
    return SprayWindowSlot(
      timeWindow: json['time_window'] ?? '',
      suitability: json['suitability'] ?? 'OPTIMAL',
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 25.0,
      windKmh: (json['wind_kmh'] as num?)?.toDouble() ?? 5.0,
      rainProbabilityPercent: json['rain_probability_percent'] ?? 0,
      advisoryReason: json['advisory_reason'] ?? '',
      deltaTC: (json['delta_t_c'] as num?)?.toDouble(),
      humidityPercent: (json['humidity_percent'] as num?)?.toDouble(),
    );
  }
}

class PunjabDistrict {
  final String id;
  final String name;
  final String punjabiName;
  final double latitude;
  final double longitude;
  final String agroZone;
  final List<String> primaryCrops;
  final String pauStation;
  final List<String> keyPestRisks;

  PunjabDistrict({
    required this.id,
    required this.name,
    required this.punjabiName,
    required this.latitude,
    required this.longitude,
    required this.agroZone,
    required this.primaryCrops,
    required this.pauStation,
    required this.keyPestRisks,
  });

  factory PunjabDistrict.fromJson(Map<String, dynamic> json) {
    return PunjabDistrict(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      punjabiName: json['punjabi_name'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 30.9010,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 75.8573,
      agroZone: json['agro_zone'] ?? 'Central Plain Zone',
      primaryCrops: (json['primary_crops'] as List? ?? []).map((e) => e.toString()).toList(),
      pauStation: json['pau_station'] ?? '',
      keyPestRisks: (json['key_pest_risks'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class WeatherAdvisory {
  final WeatherSnapshot currentWeather;
  final List<SprayWindowSlot> upcomingWindows;
  final String pestPressureForecast;
  final String? microclimateAlert;
  final String punjabAgroZone;
  final String deltaTStatus;

  WeatherAdvisory({
    required this.currentWeather,
    required this.upcomingWindows,
    required this.pestPressureForecast,
    this.microclimateAlert,
    this.punjabAgroZone = "Central Plain Zone (PAU Ludhiana)",
    this.deltaTStatus = "OPTIMAL_SPRAY_WINDOW",
  });

  factory WeatherAdvisory.fromJson(Map<String, dynamic> json) {
    return WeatherAdvisory(
      currentWeather: WeatherSnapshot.fromJson(json['current_weather'] ?? {}),
      upcomingWindows: (json['upcoming_windows'] as List? ?? [])
          .map((w) => SprayWindowSlot.fromJson(w))
          .toList(),
      pestPressureForecast: json['pest_pressure_forecast'] ?? '',
      microclimateAlert: json['microclimate_alert'],
      punjabAgroZone: json['punjab_agro_zone'] ?? 'Central Plain Zone (PAU Ludhiana)',
      deltaTStatus: json['delta_t_status'] ?? 'OPTIMAL_SPRAY_WINDOW',
    );
  }
}
