import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class OfflineStorageService {
  static final OfflineStorageService _instance = OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  Future<File> _getFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  // ==========================================
  // 1. PENDING OFFLINE LOGS QUEUE
  // ==========================================

  Future<List<Map<String, dynamic>>> getPendingVoiceLogs() async {
    try {
      final file = await _getFile('offline_pending_logs.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(content);
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint("[OfflineStorageService] Error reading pending logs: $e");
    }
    return [];
  }

  Future<void> savePendingVoiceLog(Map<String, dynamic> log) async {
    try {
      final pending = await getPendingVoiceLogs();
      // Deduplicate by log_id or id
      final newId = (log['id'] ?? log['log_id'] ?? '').toString();
      pending.removeWhere((item) => (item['id'] ?? item['log_id'] ?? '').toString() == newId);
      pending.insert(0, log);

      final file = await _getFile('offline_pending_logs.json');
      await file.writeAsString(jsonEncode(pending));
      debugPrint("[OfflineStorageService] Saved log $newId to offline queue (Total: ${pending.length})");
    } catch (e) {
      debugPrint("[OfflineStorageService] Error saving pending log: $e");
    }
  }

  Future<void> removePendingLog(String logId) async {
    try {
      final pending = await getPendingVoiceLogs();
      pending.removeWhere((item) => (item['id'] ?? item['log_id'] ?? '').toString() == logId);
      final file = await _getFile('offline_pending_logs.json');
      await file.writeAsString(jsonEncode(pending));
      debugPrint("[OfflineStorageService] Removed log $logId from offline queue");
    } catch (e) {
      debugPrint("[OfflineStorageService] Error removing pending log: $e");
    }
  }

  Future<void> clearPendingLogs() async {
    try {
      final file = await _getFile('offline_pending_logs.json');
      if (await file.exists()) {
        await file.writeAsString(jsonEncode([]));
      }
    } catch (e) {
      debugPrint("[OfflineStorageService] Error clearing pending logs: $e");
    }
  }

  // ==========================================
  // 2. CACHED COMMUNITY LOGS
  // ==========================================

  Future<void> cacheCommunityLogs(List<Map<String, dynamic>> logs) async {
    if (logs.isEmpty) return;
    try {
      final file = await _getFile('cached_community_logs.json');
      await file.writeAsString(jsonEncode(logs));
      debugPrint("[OfflineStorageService] Cached ${logs.length} community logs locally");
    } catch (e) {
      debugPrint("[OfflineStorageService] Error caching community logs: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getCachedCommunityLogs() async {
    try {
      final file = await _getFile('cached_community_logs.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(content);
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint("[OfflineStorageService] Error reading cached community logs: $e");
    }
    return [];
  }

  // ==========================================
  // 3. CACHED FARMER PERSONAL LOGS (JOURNAL)
  // ==========================================

  Future<void> cacheFarmerLogs(String phone, List<Map<String, dynamic>> logs) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return;
    try {
      final file = await _getFile('cached_farmer_logs_$cleanPhone.json');
      await file.writeAsString(jsonEncode(logs));
      debugPrint("[OfflineStorageService] Cached ${logs.length} logs for farmer $cleanPhone");
    } catch (e) {
      debugPrint("[OfflineStorageService] Error caching farmer logs: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getCachedFarmerLogs(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) return [];
    try {
      final file = await _getFile('cached_farmer_logs_$cleanPhone.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> decoded = jsonDecode(content);
          return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint("[OfflineStorageService] Error reading cached farmer logs: $e");
    }
    return [];
  }
}
