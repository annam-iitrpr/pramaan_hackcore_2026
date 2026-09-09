import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/evidence_provider.dart';
import '../core/providers/sync_provider.dart';
import '../core/localization/app_translations.dart';
import '../widgets/evidence_card.dart';
import '../widgets/custom_bottom_nav.dart';

class EvidenceReviewScreen extends StatelessWidget {
  const EvidenceReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final evProv = Provider.of<EvidenceProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final syncProv = Provider.of<SyncProvider>(context);
    final lang = auth.selectedLanguage;

    final filterOptions = [
      {'code': 'ALL', 'label': AppTranslations.tr(lang, 'filter_all', 'ALL')},
      {'code': 'VERIFIED', 'label': AppTranslations.tr(lang, 'filter_verified', 'VERIFIED')},
      {'code': 'PENDING', 'label': AppTranslations.tr(lang, 'filter_pending', 'PENDING')},
      {'code': 'FLAGGED', 'label': AppTranslations.tr(lang, 'filter_flagged', 'NEEDS REVIEW')},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/farmer_dashboard');
            }
          },
        ),
        title: Text(
          AppTranslations.tr(lang, 'evidence_pipeline_title', "Evidence Verification Pipeline"),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF047857), size: 20),
              tooltip: "Audit Report",
              onPressed: () => Navigator.pushNamed(context, '/evidence_report'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: -1),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filterOptions.map((f) {
                  final code = f['code']!;
                  final label = f['label']!;
                  final isSelected = evProv.selectedFilter == code;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      onTap: () => evProv.setFilter(code),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF047857) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Offline Sync Alert (if pending items)
          if (syncProv.pendingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFEF3C7),
              child: Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 18, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppTranslations.tr(lang, "offline_logs_pending", "{count} offline logs pending cloud sync").replaceAll("{count}", syncProv.pendingCount.toString()),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                  ),
                  InkWell(
                    onTap: syncProv.isSyncing
                        ? null
                        : () async {
                            final count = await syncProv.syncAll();
                            if (count > 0 && context.mounted) {
                              evProv.loadEvidenceForFarmer(phone: auth.userPhone, name: auth.userName);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF065F46),
                                  content: Text("✓ $count"),
                                ),
                              );
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB45309),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: syncProv.isSyncing
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                            )
                          : Text(
                              AppTranslations.tr(lang, "sync_now", "Sync Now"),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),

          // Info Banner: "Track the verification status of your spray and farm activities."
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD1FAE5), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.spa_rounded, color: Color(0xFF047857), size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppTranslations.tr(lang, "track_verification_status", "Track the verification status of your spray and farm activities."),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF065F46),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sun & Leaves decorative illustration
                  SizedBox(
                    width: 50,
                    height: 38,
                    child: Stack(
                      children: [
                        Positioned(
                          right: 4,
                          top: 2,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFBBF24),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(
                            Icons.eco_rounded,
                            size: 26,
                            color: const Color(0xFF047857).withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Evidence List
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF047857),
              onRefresh: () async {
                await evProv.loadEvidenceForFarmer(phone: auth.userPhone, name: auth.userName);
              },
              child: evProv.isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF047857)))
                  : evProv.evidenceList.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.folder_open_rounded, size: 48, color: AppColors.textMuted),
                                  const SizedBox(height: 12),
                                  Text(
                                    AppTranslations.tr(lang, "no_evidence_found", "No {filter} evidence items found.").replaceAll("{filter}", evProv.selectedFilter),
                                    style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: evProv.evidenceList.length,
                          itemBuilder: (context, index) {
                            final item = evProv.evidenceList[index];
                            return EvidenceCard(
                              item: item,
                              onTap: () => Navigator.pushNamed(context, '/evidence_detail', arguments: item),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
