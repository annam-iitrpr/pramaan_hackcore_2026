import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'offline_storage_service.dart';

class GoogleSheetsService {
  static final GoogleSheetsService _instance = GoogleSheetsService._internal();
  factory GoogleSheetsService() => _instance;
  GoogleSheetsService._internal();

  // Active Google Apps Script Webhook URL
  String? _customWebhookUrl;

  void setCustomWebhookUrl(String url) {
    _customWebhookUrl = url.trim();
  }

  String get currentWebhookUrl =>
      _customWebhookUrl ??
      "https://script.google.com/macros/s/AKfycbyOODzqfRrLXNPV4BB7av2P4DncYniqln-Qy98CauxCsxeGiNe_zX1sF9_PmToi92QJ/exec";

  /// Sends a POST request and manually follows 302/301/307 redirects for Google Apps Script
  Future<http.Response> _postWithRedirect(String url, Map<String, dynamic> bodyJson, {int timeoutSec = 15}) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(url);
      final response = await client
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(bodyJson),
          )
          .timeout(Duration(seconds: timeoutSec));

      if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 307 || response.statusCode == 308) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          return await client
              .post(
                Uri.parse(redirectUrl),
                headers: {"Content-Type": "application/json"},
                body: jsonEncode(bodyJson),
              )
              .timeout(Duration(seconds: timeoutSec));
        }
      }

      return response;
    } finally {
      client.close();
    }
  }

  /// Sends a GET request and manually follows 302/301/307 redirects for Google Apps Script
  Future<http.Response> _getWithRedirect(String url, {int timeoutSec = 15}) async {
    final client = http.Client();
    try {
      final uri = Uri.parse(url);
      final response = await client.get(uri).timeout(Duration(seconds: timeoutSec));

      if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 307 || response.statusCode == 308) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null && redirectUrl.isNotEmpty) {
          return await client.get(Uri.parse(redirectUrl)).timeout(Duration(seconds: timeoutSec));
        }
      }

      return response;
    } finally {
      client.close();
    }
  }

  /// Passwordless Farmer Login or Auto-Registration via Google Apps Script (Farmers Tab)
  Future<Map<String, dynamic>> loginOrRegisterFarmer({
    required String name,
    required String phone,
    String village = "Dindori, Nashik",
    String state = "Maharashtra",
    String crop = "Cotton (Bt-II)",
    double acres = 12.5,
  }) async {
    final payload = {
      "action": "farmer_login",
      "farmer_name": name,
      "farmer_phone": phone,
      "village": village,
      "state": state,
      "crop": crop,
      "acres": acres,
      "timestamp": DateTime.now().toUtc().toIso8601String(),
    };

    debugPrint("[Google Sheets Service] Posting farmer login to $currentWebhookUrl: ${jsonEncode(payload)}");

    try {
      final response = await _postWithRedirect(currentWebhookUrl, payload);
      debugPrint("[Google Sheets Service] Login response (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        return data;
      }
    } catch (e) {
      debugPrint("[Google Sheets Service] Online sync notice: $e.");
    }

    // Fallback response for offline resilience
    return {
      "status": "success",
      "is_new_farmer": true,
      "farmer": {
        "name": name,
        "phone": phone,
        "village": village,
        "state": state,
        "crop": crop,
        "acres": acres,
        "last_login": DateTime.now().toUtc().toIso8601String(),
        "total_logs": 0,
      },
      "logs": []
    };
  }

  /// Fetch Logs specifically for the Logged-in Farmer from Google Sheets (Farmer_Logs Tab)
  Future<List<Map<String, dynamic>>> fetchFarmerLogs({
    required String phone,
    String? name,
  }) async {
    final encodedPhone = Uri.encodeComponent(phone.trim());
    final encodedName = name != null ? Uri.encodeComponent(name.trim()) : "";
    final getUrl = "$currentWebhookUrl?action=get_farmer_logs&phone=$encodedPhone&name=$encodedName";

    debugPrint("[Google Sheets Service] Fetching farmer logs from: $getUrl");

    try {
      final response = await _getWithRedirect(getUrl, timeoutSec: 4);
      debugPrint("[Google Sheets Service] Fetch logs response (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['logs'] is List) {
          final logs = List<Map<String, dynamic>>.from(data['logs']);
          await OfflineStorageService().cacheFarmerLogs(phone, logs);
          return logs;
        }
      }
    } catch (e) {
      debugPrint("[Google Sheets Service] fetchFarmerLogs notice (falling back to offline cache): $e");
    }

    // Offline cache fallback
    final cached = await OfflineStorageService().getCachedFarmerLogs(phone);
    if (cached.isNotEmpty) {
      debugPrint("[Google Sheets Service] Loaded ${cached.length} farmer logs from local offline cache");
      return cached;
    }
    return [];
  }

  /// Fetch All Verified Logs across All Farmers from the Google Sheet ONLY (with Offline Cache Fallback)
  Future<List<Map<String, dynamic>>> fetchAllCommunityLogs() async {
    final getUrl = "$currentWebhookUrl?action=get_farmer_logs";
    debugPrint("[Google Sheets Service] Fetching live community logs from Sheet: $getUrl");

    try {
      final response = await _getWithRedirect(getUrl, timeoutSec: 4);
      debugPrint("[Google Sheets Service] Community logs response (${response.statusCode}): ${response.body}");

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['logs'] is List) {
          final List<Map<String, dynamic>> rawList =
              List<Map<String, dynamic>>.from(data['logs']);

          // Filter out header rows and empty logs from the sheet
          final validLogs = rawList.where((log) {
            final fName = (log['farmer_name'] ?? '').toString().trim();
            final logId = (log['id'] ?? log['log_id'] ?? '').toString().trim();
            if (fName.isEmpty || fName == 'Farmer Name' || logId == 'Log ID' || fName.toLowerCase() == 'name') {
              return false;
            }
            return true;
          }).toList();

          if (validLogs.isNotEmpty) {
            await OfflineStorageService().cacheCommunityLogs(validLogs);
          }
          return validLogs;
        }
      }
    } catch (e) {
      debugPrint("[Google Sheets Service] fetchAllCommunityLogs error (falling back to offline cache): $e");
    }

    // Offline cache fallback
    final cached = await OfflineStorageService().getCachedCommunityLogs();
    if (cached.isNotEmpty) {
      debugPrint("[Google Sheets Service] Loaded ${cached.length} community logs from local offline cache");
      return cached;
    }

    return [];
  }

  /// Appends a new voice observation entry to Google Sheets (or saves to offline queue if offline)
  Future<bool> logFarmerVoiceEntry({
    required String farmerName,
    required String farmerPhone,
    required String village,
    required String state,
    required String crop,
    required String actionType,
    required String? productName,
    required String? dosage,
    required String? targetPest,
    required String voiceTranscript,
    required double complianceScore,
    required String verificationStatus,
    required String reportId,
    required String hashAnchor,
  }) async {
    final payload = {
      "action": "add_voice_log",
      "timestamp": DateTime.now().toUtc().toIso8601String(),
      "log_id": "LOG-${DateTime.now().millisecondsSinceEpoch}",
      "farmer_name": farmerName,
      "farmer_phone": farmerPhone,
      "village": village,
      "state": state,
      "crop": crop,
      "action_type": actionType,
      "product_name": productName ?? "Bio-Neem Power 10000 PPM",
      "dosage": dosage ?? "400 ml in 200L Water / Acre",
      "target_pest": targetPest ?? "Whitefly",
      "voice_transcript": voiceTranscript,
      "compliance_score": complianceScore,
      "verification_status": verificationStatus,
      "report_id": reportId,
      "hash_anchor": hashAnchor,
    };

    debugPrint("[Google Sheets Service] Posting voice log to $currentWebhookUrl: ${jsonEncode(payload)}");

    try {
      final response = await _postWithRedirect(currentWebhookUrl, payload, timeoutSec: 4);
      debugPrint("[Google Sheets Service] Add log response (${response.statusCode}): ${response.body}");
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') return true;
      }
      if (response.statusCode == 200) return true;
    } catch (e) {
      debugPrint("[Google Sheets Service] Direct sync notice: $e. Saving to offline queue.");
    }

    // Save to local offline queue for sync when internet is restored
    await OfflineStorageService().savePendingVoiceLog(payload);
    return false;
  }

  /// Drains the local offline queue by uploading pending voice logs to Google Sheets
  Future<int> syncPendingOfflineLogs() async {
    final pending = await OfflineStorageService().getPendingVoiceLogs();
    if (pending.isEmpty) return 0;

    int syncedCount = 0;
    for (var log in List<Map<String, dynamic>>.from(pending)) {
      final logId = (log['id'] ?? log['log_id'] ?? '').toString();
      try {
        final response = await _postWithRedirect(currentWebhookUrl, log, timeoutSec: 4);
        if (response.statusCode == 200) {
          await OfflineStorageService().removePendingLog(logId);
          syncedCount++;
        }
      } catch (e) {
        debugPrint("[Google Sheets Service] Error syncing offline log $logId: $e");
      }
    }
    return syncedCount;
  }
}
