import 'package:flutter/material.dart';
import '../../models/evidence_model.dart';
import '../services/api_service.dart';
import '../services/google_sheets_service.dart';

class EvidenceProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final GoogleSheetsService _sheets = GoogleSheetsService();
  List<EvidenceItem> _evidenceList = [];
  bool _isLoading = false;
  String _selectedFilter = 'ALL'; // ALL, VERIFIED, PENDING, FLAGGED
  String? _activeFarmerPhone;
  String? _activeFarmerName;

  bool _matchesFarmer(EvidenceItem item) {
    if ((_activeFarmerPhone == null || _activeFarmerPhone!.isEmpty) &&
        (_activeFarmerName == null || _activeFarmerName!.isEmpty)) {
      return true;
    }

    // Normalize phone numbers (digits only)
    final activeDigits =
        _activeFarmerPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    final itemDigits =
        item.farmerPhone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';

    bool phoneMatch = false;
    if (activeDigits.isNotEmpty && itemDigits.isNotEmpty) {
      if (activeDigits == itemDigits ||
          (activeDigits.length >= 10 &&
              itemDigits.endsWith(
                activeDigits.substring(activeDigits.length - 10),
              )) ||
          (itemDigits.length >= 10 &&
              activeDigits.endsWith(
                itemDigits.substring(itemDigits.length - 10),
              ))) {
        phoneMatch = true;
      }
    }

    final activeNameNorm = _activeFarmerName?.trim().toLowerCase() ?? '';
    final itemNameNorm = item.farmerName?.trim().toLowerCase() ?? '';
    bool nameMatch = false;
    if (activeNameNorm.isNotEmpty && itemNameNorm.isNotEmpty) {
      if (activeNameNorm == itemNameNorm ||
          activeNameNorm.contains(itemNameNorm) ||
          itemNameNorm.contains(activeNameNorm)) {
        nameMatch = true;
      }
    }

    return phoneMatch || nameMatch;
  }

  List<EvidenceItem> get evidenceList {
    List<EvidenceItem> baseList = _evidenceList;

    // Filter strictly by logged-in farmer if active
    if ((_activeFarmerPhone != null && _activeFarmerPhone!.isNotEmpty) ||
        (_activeFarmerName != null && _activeFarmerName!.isNotEmpty)) {
      baseList = baseList.where((e) => _matchesFarmer(e)).toList();
    }

    if (_selectedFilter == 'ALL') return baseList;
    return baseList
        .where((e) => e.verificationStatus == _selectedFilter)
        .toList();
  }

  List<EvidenceItem> get allEvidence => _evidenceList;
  bool get isLoading => _isLoading;
  String get selectedFilter => _selectedFilter;

  EvidenceProvider() {
    // Initialized clean without dummy seeds
  }

  void setActiveFarmer({required String phone, required String name}) {
    _activeFarmerPhone = phone.trim();
    _activeFarmerName = name.trim();
    loadEvidenceForFarmer(phone: phone, name: name);
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  Future<void> loadEvidence() async {
    if (_activeFarmerPhone != null && _activeFarmerPhone!.isNotEmpty) {
      await loadEvidenceForFarmer(phone: _activeFarmerPhone!, name: _activeFarmerName ?? '');
    }
  }

  Future<void> loadEvidenceForFarmer({
    required String phone,
    required String name,
  }) async {
    final cleanPhone = phone.trim();
    final cleanName = name.trim();
    _activeFarmerPhone = cleanPhone;
    _activeFarmerName = cleanName;
    _isLoading = true;
    notifyListeners();

    List<EvidenceItem> fetchedLogs = [];

    // 1. Fetch real logs from MongoDB Atlas
    try {
      final mongoLogs = await _api.fetchFarmerLogsMongo(cleanPhone);
      if (mongoLogs.isNotEmpty) {
        fetchedLogs = mongoLogs.map((json) => EvidenceItem.fromJson(json)).toList();
        debugPrint("[Evidence Provider] Loaded ${fetchedLogs.length} real logs from MongoDB Atlas");
      }
    } catch (e) {
      debugPrint("[Evidence Provider] MongoDB logs fetch notice: $e");
    }

    // 2. Fallback to Google Sheets if MongoDB returned empty
    if (fetchedLogs.isEmpty) {
      try {
        final sheetLogs = await _sheets.fetchFarmerLogs(phone: cleanPhone, name: cleanName);
        if (sheetLogs.isNotEmpty) {
          fetchedLogs = sheetLogs.map((json) => EvidenceItem.fromJson(json)).toList();
          debugPrint("[Evidence Provider] Loaded ${fetchedLogs.length} logs from Google Sheets");
        }
      } catch (e) {
        debugPrint("[Evidence Provider] Sheet logs fetch notice: $e");
      }
    }

    // Strictly set the evidence list for this farmer (no dummy items)
    _evidenceList = fetchedLogs;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addEvidence({
    required String title,
    required String description,
    required String evidenceType,
    String? mediaUrl,
    String? audioTranscript,
    String? productQr,
    String? productName,
    String? dosagePerAcre,
    String? farmerName,
    String? farmerPhone,
    String? village,
    String? cropName,
  }) async {
    // Do not fabricate identity, crop, location, weather,
    // verification status, score, or hash.

    final effectiveName = farmerName ?? _activeFarmerName;

    final effectivePhone = farmerPhone ?? _activeFarmerPhone;

    final newId = 'EV-${DateTime.now().millisecondsSinceEpoch}';

    final newItem = EvidenceItem(
      id: newId,

      // Farm ID is unknown unless it actually comes from
      // authenticated farm context/backend.
      farmId: '',

      // Crop remains empty if it wasn't extracted.
      cropName: cropName ?? '',

      // Do not invent crop stage.
      cropStage: '',

      evidenceType: evidenceType,

      timestamp: DateTime.now().toUtc().toIso8601String(),

      // No fake GPS.
      location: GeoLocation(
        latitude: 0.0,
        longitude: 0.0,
        fieldName: '',
        village: village ?? '',
      ),

      // Do not invent weather.
      weather: WeatherSnapshot(
        temperatureC: 0.0,
        humidityPercent: 0.0,
        windSpeedKmh: 0.0,
        precipitationProb: 0.0,
        condition: '',
        spraySuitabilityScore: 0.0,
        sprayRecommendation: '',
      ),

      title: title,
      description: description,

      mediaUrl: mediaUrl,
      audioTranscript: audioTranscript,
      productQr: productQr,

      // Actual extracted values only.
      productName: productName,
      dosagePerAcre: dosagePerAcre,

      farmerName: effectiveName,
      farmerPhone: effectivePhone,

      // Extraction is not verification.
      verificationStatus: 'EXTRACTED',

      // No confidence/compliance score here.
      verificationScore: 0.0,

      // No fabricated hash.
      verificationHash: '',

      // Only state what actually happened.
      agentVerdicts: {
        'voice_agent': 'Observation extracted from farmer voice input.',
      },
    );

    // Add locally first so offline-first behavior works.
    _evidenceList.insert(0, newItem);
    notifyListeners();

    // Submit exactly what we have.
    try {
      await _api.submitEvidence(newItem.toJson());
    } catch (e) {
      debugPrint("[Evidence Provider] Evidence submission failed: $e");
    }
  }

  void updateStatus(
    String evidenceId,
    String newStatus, {
    double score = 96.0,
    List<String>? reasons,
  }) {
    for (var ev in _evidenceList) {
      if (ev.id == evidenceId) {
        ev.verificationStatus = newStatus;
        ev.verificationScore = score;
        break;
      }
    }
    notifyListeners();
  }
}
