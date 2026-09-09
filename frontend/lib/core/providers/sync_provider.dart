import 'package:flutter/material.dart';
import '../services/offline_storage_service.dart';
import '../services/google_sheets_service.dart';

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
      final pendingLogs = await _storage.getPendingVoiceLogs();
      _syncQueue = pendingLogs.map((log) {
        final id = (log['id'] ?? log['log_id'] ?? 'Q-OFFLINE').toString();
        final crop = (log['crop'] ?? 'Crop').toString();
        final action = (log['action_type'] ?? 'SPRAY').toString();
        final product = (log['product_name'] ?? 'Agri-Input').toString();

        return PendingSyncItem(
          id: id,
          title: "Voice Log: $action $crop ($product)",
          type: "VOICE_EVIDENCE",
          timestamp: log['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
          sizeKb: "18.4 KB",
          status: "PENDING",
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

      syncedCount = await _sheets.syncPendingOfflineLogs();
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
