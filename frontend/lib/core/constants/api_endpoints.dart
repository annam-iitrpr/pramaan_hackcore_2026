class ApiEndpoints {
  // Configurable base URL. Default to localhost for web/desktop, 10.0.2.2 for Android emulator, or LAN IP for physical device.
  static String _customBaseUrl = "http://127.0.0.1:8000/api/v1";

  static String get baseUrl => _customBaseUrl;

  static void setBaseUrl(String newUrl) {
    if (newUrl.endsWith('/')) {
      _customBaseUrl = "${newUrl}api/v1";
    } else if (!newUrl.contains('/api/v1')) {
      _customBaseUrl = "$newUrl/api/v1";
    } else {
      _customBaseUrl = newUrl;
    }
  }

  // Dynamic route getters
  static String get orchestratorChat => "$baseUrl/orchestrator/chat";
  static String get voiceProcess => "$baseUrl/voice/process";
  static String get visionAnalyze => "$baseUrl/vision/analyze";
  static String get validationVerify => "$baseUrl/validation/verify";
  static String get evidenceList => "$baseUrl/validation/evidence";
  static String get evidenceCreate => "$baseUrl/validation/evidence/create";
  static String get learningFeedback => "$baseUrl/validation/learning-feedback";
  static String get efficacyCompute => "$baseUrl/efficacy/compute";
  static String get weatherAdvisory => "$baseUrl/weather/advisory";
  static String get reportGenerate => "$baseUrl/report/generate";
  static String get farmsList => "$baseUrl/farm/farms";
  static String get productsList => "$baseUrl/farm/products";
  static String get productLookup => "$baseUrl/farm/products/lookup";
  static String get journalList => "$baseUrl/farm/journal";
  static String get journalCreate => "$baseUrl/farm/journal/create";
  static String get notifications => "$baseUrl/farm/notifications";
  static String get buyerPricing => "$baseUrl/farm/buyer-pricing";
}

