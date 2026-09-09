import 'package:flutter/material.dart';
import '../services/offline_storage_service.dart';
import '../services/google_sheets_service.dart';
import '../services/api_service.dart';

class PendingSyncItem {
  final String id;
  final String title;
  final String type;
  final String timestamp;
  final String sizeKb;
  String status; // PENDING, SYNCING, SYNCED, FAILED
  final Map<String, dynamic>? rawPayload;

  PendingSyncItem({
    required this.id,
    required this.title,
    required this.type,
    required this.timestamp,
    required this.sizeKb,
    this.status = 'PENDING',
    this.rawPayload,
  });
}

class SyncProvider extends ChangeNotifier {
  final OfflineStorageService _storage = OfflineStorageService();
  final GoogleSheetsService _sheets = GoogleSheetsService();
  final ApiService _api = ApiService();

  bool _isOnline = true;
  bool _isSyncing = false;
  List<PendingSyncItem> _syncQueue = [];

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  List<PendingSyncItem> get syncQueue => _syncQueue;
  int get pendingCount => _syncQueue.where((i) => i.status == 'PENDING').length;

  SyncProvider() {
    loadOfflineQueue();
  }

  Future<void> loadOfflineQueue() async {
    try {
      final pendingLogs = await _storage.getPendingLogs();
      _syncQueue = pendingLogs.map((log) {
        final id = (log['id'] ?? log['log_id'] ?? 'Q-OFFLINE').toString();
        final title = (log['title'] ?? log['crop_type'] ?? 'Spray Action Log').toString();
        final type = (log['action_type'] ?? log['type'] ?? 'SPRAY_ACTION').toString();
        final ts = (log['timestamp'] ?? DateTime.now().toIso8601String()).toString();
        final size = "${(log.toString().length / 1024).toStringAsFixed(1)} KB";

        return PendingSyncItem(
          id: id,
          title: title,
          type: type,
          timestamp: ts,
          sizeKb: size,
          status: 'PENDING',
          rawPayload: log,
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("[SyncProvider] Error loading queue: $e");
    }
  }

  void toggleNetwork(bool online) {
    _isOnline = online;
    notifyListeners();
    if (online) {
      syncAll();
    }
  }

  Future<int> syncAll() async {
    if (_isSyncing) return 0;
    _isSyncing = true;
    notifyListeners();

    int syncedCount = 0;
    try {
      for (var item in _syncQueue) {
        item.status = 'SYNCING';
      }
      notifyListeners();

      final pendingLogs = await _storage.getPendingLogs();
      if (pendingLogs.isNotEmpty) {
        try {
          // 1. Primary Sync: MongoDB Database via FastAPI Backend
          final res = await _api.syncBatchMongo(logs: pendingLogs);
          if (res['status'] == 'success') {
            syncedCount = res['synced_count'] ?? pendingLogs.length;
            debugPrint("[SyncProvider] Synced $syncedCount logs to MongoDB successfully!");
          }
        } catch (mErr) {
          debugPrint("[SyncProvider] MongoDB sync notice: $mErr. Mirroring to Google Sheets.");
        }

        // 2. Secondary/Mirror Sync: Google Sheets
        try {
          final sheetsCount = await _sheets.syncPendingOfflineLogs();
          if (syncedCount == 0) syncedCount = sheetsCount;
        } catch (_) {}

        if (syncedCount > 0) {
          await _storage.clearPendingLogs();
        }
      }

      await loadOfflineQueue();
    } catch (e) {
      debugPrint("[SyncProvider] Sync error: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
    return syncedCount;
  }

  Future<void> clearSynced() async {
    await _storage.clearPendingLogs();
    await loadOfflineQueue();
  }
}
