import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/sync_provider.dart';

class SyncCenterScreen extends StatelessWidget {
  const SyncCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = Provider.of<SyncProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Offline Sync Center",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Network Connectivity Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sync.isOnline
                          ? AppColors.primarySurface
                          : const Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      sync.isOnline
                          ? Icons.wifi_rounded
                          : Icons.wifi_off_rounded,
                      color: sync.isOnline
                          ? AppColors.primary
                          : AppColors.flaggedRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sync.isOnline
                              ? "Online (Server Connected)"
                              : "Offline Mode (Local Storage)",
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          sync.isOnline
                              ? "FastAPI backend reachable at :8000"
                              : "Logs stored locally on device cache",
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: sync.isOnline,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => sync.toggleNetwork(val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sync Queue Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Pending Upload Queue (${sync.pendingCount})",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (sync.syncQueue.any((i) => i.status == 'SYNCED'))
                  TextButton(
                    onPressed: () => sync.clearSynced(),
                    child: const Text("Clear Synced"),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (sync.syncQueue.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.cloud_done_rounded,
                      color: AppColors.primary,
                      size: 40,
                    ),
                    SizedBox(height: 8),
                    Text(
                      "All Records Up to Date",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              ...sync.syncQueue.map((item) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(
                      item.type == 'VOICE_AUDIO'
                          ? Icons.mic_rounded
                          : Icons.image_rounded,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      "${item.timestamp} • ${item.sizeKb}",
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: item.status == 'SYNCING'
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : item.status == 'SYNCED'
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                          )
                        : const Text(
                            "QUEUED",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accentAmber,
                            ),
                          ),
                  ),
                );
              }),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: sync.isSyncing ? null : () => sync.syncAll(),
                icon: sync.isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(
                  sync.isSyncing
                      ? "SYNCING TO PRAMAAN CLOUD..."
                      : "SYNC ALL PENDING EVIDENCE",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
