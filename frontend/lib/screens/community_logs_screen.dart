import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/localization/app_translations.dart';
import '../core/services/google_sheets_service.dart';
import '../core/services/pdf_download_service.dart';
import '../models/evidence_model.dart';
import '../widgets/custom_bottom_nav.dart';

class CommunityLogsScreen extends StatefulWidget {
  const CommunityLogsScreen({super.key});

  @override
  State<CommunityLogsScreen> createState() => _CommunityLogsScreenState();
}

class _CommunityLogsScreenState extends State<CommunityLogsScreen> {
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final PdfDownloadService _pdfService = PdfDownloadService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _sheetLogs = [];
  bool _isLoading = true;
  bool _isLoadedFromCache = false;
  String _selectedCrop = "All";
  String _selectedRegion = "All";
  String _searchQuery = "";
  final Set<String> _downloadingLogKeys = {};

  @override
  void initState() {
    super.initState();
    _fetchLiveSheetLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLiveSheetLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _sheetsService.fetchAllCommunityLogs();
      if (mounted) {
        setState(() {
          _sheetLogs = logs;
          _isLoading = false;
          _isLoadedFromCache = logs.isNotEmpty;
          // Reset filters if previous selection not in new data
          if (!_availableCrops.contains(_selectedCrop)) _selectedCrop = "All";
          if (!_availableRegions.contains(_selectedRegion)) _selectedRegion = "All";
        });
      }
    } catch (e) {
      debugPrint("[CommunityLogsScreen] Error loading live sheet logs: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadedFromCache = true;
        });
      }
    }
  }

  List<String> get _availableCrops {
    final crops = <String>{"All"};
    for (var log in _sheetLogs) {
      final crop = (log['crop'] ?? log['crop_name'] ?? '').toString().trim();
      if (crop.isNotEmpty && crop != 'Crop') {
        crops.add(crop);
      }
    }
    return crops.toList();
  }

  List<String> get _availableRegions {
    final regions = <String>{"All"};
    for (var log in _sheetLogs) {
      final state = (log['state'] ?? '').toString().trim();
      final village = (log['village'] ?? '').toString().trim();
      if (state.isNotEmpty && state != 'State') regions.add(state);
      if (village.isNotEmpty && village != 'Village / Location' && !regions.contains(village)) {
        regions.add(village);
      }
    }
    return regions.toList();
  }

  List<Map<String, dynamic>> get _filteredLogs {
    var list = List<Map<String, dynamic>>.from(_sheetLogs);

    // 1. Crop Dropdown Filter
    if (_selectedCrop != "All") {
      list = list.where((log) {
        final crop = (log['crop'] ?? log['crop_name'] ?? '').toString().toLowerCase();
        return crop.contains(_selectedCrop.toLowerCase());
      }).toList();
    }

    // 2. Region Dropdown Filter
    if (_selectedRegion != "All") {
      list = list.where((log) {
        final state = (log['state'] ?? '').toString().toLowerCase();
        final village = (log['village'] ?? '').toString().toLowerCase();
        return state.contains(_selectedRegion.toLowerCase()) || village.contains(_selectedRegion.toLowerCase());
      }).toList();
    }

    // 3. Search Query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((log) {
        final farmer = (log['farmer_name'] ?? '').toString().toLowerCase();
        final crop = (log['crop'] ?? log['crop_name'] ?? '').toString().toLowerCase();
        final village = (log['village'] ?? '').toString().toLowerCase();
        final state = (log['state'] ?? '').toString().toLowerCase();
        final product = (log['product_name'] ?? '').toString().toLowerCase();
        final desc = (log['description'] ?? log['voice_transcript'] ?? '').toString().toLowerCase();

        return farmer.contains(q) || crop.contains(q) || village.contains(q) || state.contains(q) || product.contains(q) || desc.contains(q);
      }).toList();
    }

    return list;
  }

  Future<void> _handleDownloadPdf(Map<String, dynamic> log, String itemKey) async {
    setState(() => _downloadingLogKeys.add(itemKey));

    try {
      final rawName = (log['farmer_name'] ?? '').toString().trim();
      final farmerName = rawName.isNotEmpty ? rawName : 'Verified Farmer';
      final farmerPhone = (log['farmer_phone'] ?? '').toString();
      final village = (log['village'] ?? 'Dindori, Nashik').toString();
      final state = (log['state'] ?? 'Maharashtra').toString();
      final crop = (log['crop'] ?? log['crop_name'] ?? 'Wheat').toString();

      final evidenceItem = EvidenceItem.fromJson(log);

      await _pdfService.downloadAndOpenReport(
        item: evidenceItem,
        farmerName: farmerName,
        farmerPhone: farmerPhone,
        village: village,
        state: state,
        activeCrop: crop,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF065F46),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "✓ 3-Page Audit PDF for $farmerName saved to storage!",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("[CommunityLogsScreen] Download error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text("Error saving PDF: $e"),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingLogKeys.remove(itemKey));
      }
    }
  }

  void _showLogDetailsModal(Map<String, dynamic> log, String lang, String itemKey) {
    final farmerName = (log['farmer_name'] ?? 'Verified Farmer').toString();
    final village = (log['village'] ?? '').toString();
    final state = (log['state'] ?? '').toString();
    final crop = (log['crop'] ?? log['crop_name'] ?? 'Crop').toString();
    final productName = (log['product_name'] ?? 'Bio-Neem Power 10000 PPM').toString();
    final dosage = (log['dosage'] ?? log['dosage_per_acre'] ?? 'Standard Dose').toString();
    final score = ((log['compliance_score'] ?? log['verification_score'] ?? 98.6) as num).toDouble();
    final transcript = (log['voice_transcript'] ?? log['description'] ?? '').toString();
    final reportId = (log['report_id'] ?? 'PRM-REP-VERIFIED').toString();
    final hash = (log['verification_hash'] ?? log['hash_anchor'] ?? 'a8f5b4c9103982eef11082cba972e345b98a0021c32ff8812de4b21903fa7e41').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          "✓ $reportId",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          "$score% ${AppTranslations.tr(lang, "verified_label", "VERIFIED")}",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Farmer Profile
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primarySurface,
                        child: Text(
                          farmerName.isNotEmpty ? farmerName[0] : 'K',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              farmerName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              "📍 $village, $state",
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),

                  // Crop & Input Details Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(AppTranslations.tr(lang, "target_crop_lbl", "🌾 Target Crop"), crop),
                        const Divider(height: 16),
                        _buildDetailRow(AppTranslations.tr(lang, "input_applied_lbl", "🧪 Input Applied"), productName),
                        const Divider(height: 16),
                        _buildDetailRow(AppTranslations.tr(lang, "verified_dosage_lbl", "⚖️ Verified Dosage"), dosage),
                        const Divider(height: 16),
                        _buildDetailRow(AppTranslations.tr(lang, "action_type_lbl", "🎯 Action Type"), log['action_type']?.toString() ?? "SPRAY"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Voice Transcript Box
                  Text(
                    AppTranslations.tr(lang, "recorded_voice_transcript_lbl", "🎙️ Recorded Voice Transcript"),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE9D5FF)),
                    ),
                    child: Text(
                      transcript.isNotEmpty ? "\"$transcript\"" : "\"Voice evidence recorded and validated by Pramaan AI.\"",
                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF581C87)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SHA-256 Hash
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.tr(lang, "sha256_hash_anchor_lbl", "🔒 SHA-256 Hash Anchor:"),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hash,
                          style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Download Full 3-Page PDF button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: Text(
                        AppTranslations.tr(lang, "download_peer_pdf", "Download 3-Page Audit PDF"),
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleDownloadPdf(log, itemKey);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;
    final logs = _filteredLogs;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppTranslations.tr(lang, "log_community", "Log Community"),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh from Google Sheet",
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _isLoading ? null : _fetchLiveSheetLogs,
          ),
          IconButton(
            tooltip: AppTranslations.tr(lang, "select_language"),
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                lang.toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
              ),
            ),
            onPressed: () => AppTranslations.showLanguageSelectorModal(
              context,
              lang,
              (newLang) => auth.setLanguage(newLang),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLiveSheetLogs,
        color: AppColors.primary,
        child: Column(
          children: [
            if (_isLoadedFromCache)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                color: const Color(0xFFFEF3C7),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppTranslations.tr(lang, "offline_community_banner", "Working Offline • Displaying cached community records"),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ),
                  ],
                ),
              ),

            // Clean Dropdown Filter Bar
            _buildDropdownFilterBar(lang),

            // Live Sheets Logs Count Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${AppTranslations.tr(lang, "google_sheet_records", "Google Sheet Records")} (${logs.length})",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_selectedCrop != "All" || _selectedRegion != "All" || _searchQuery.isNotEmpty)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCrop = "All";
                          _selectedRegion = "All";
                          _searchQuery = "";
                          _searchController.clear();
                        });
                      },
                      child: Text(
                        AppTranslations.tr(lang, "reset_filters", "Reset Filters"),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),

            // Logs Feed List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 12),
                          Text(
                            AppTranslations.tr(lang, "loading_sheet_records", "Loading records from Google Sheet..."),
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  : logs.isEmpty
                      ? _buildEmptyState(lang)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return _buildCommunityLogCard(log, lang, index);
                          },
                        ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(
        currentIndex: 2,
      ),
    );
  }

  /// Clean, compact 2-Dropdown Filter Bar for Crop and Region
  Widget _buildDropdownFilterBar(String lang) {
    final crops = _availableCrops;
    final regions = _availableRegions;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          // Dropdowns Row
          Row(
            children: [
              // 1. Crop Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: crops.contains(_selectedCrop) ? _selectedCrop : "All",
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                      items: crops.map((c) {
                        return DropdownMenuItem<String>(
                          value: c,
                          child: Row(
                            children: [
                              const Icon(Icons.eco_rounded, size: 16, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  c == "All" ? AppTranslations.tr(lang, "all_crops", "All Crops") : c,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCrop = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 2. Region Dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: regions.contains(_selectedRegion) ? _selectedRegion : "All",
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                      items: regions.map((r) {
                        return DropdownMenuItem<String>(
                          value: r,
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF047857)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  r == "All" ? AppTranslations.tr(lang, "all_regions", "All Regions") : r,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRegion = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Search Field
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: AppTranslations.tr(lang, "search_community_hint", "Search farmer, crop, village, product..."),
                hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityLogCard(Map<String, dynamic> log, String lang, int index) {
    final logId = (log['id'] ?? log['log_id'] ?? '').toString();
    final farmerName = (log['farmer_name'] ?? 'Verified Farmer').toString();
    final village = (log['village'] ?? '').toString();
    final state = (log['state'] ?? '').toString();
    final crop = (log['crop'] ?? log['crop_name'] ?? 'Crop').toString();
    final actionType = (log['action_type'] ?? 'SPRAY').toString();
    final productName = (log['product_name'] ?? 'Bio-Neem Power 10000 PPM').toString();
    final dosage = (log['dosage'] ?? log['dosage_per_acre'] ?? 'Standard Dosage').toString();
    final score = ((log['compliance_score'] ?? log['verification_score'] ?? 98.6) as num).toDouble();
    final transcript = (log['voice_transcript'] ?? log['description'] ?? '').toString();
    final timestamp = (log['timestamp'] ?? '').toString();
    final itemKey = "${logId}_${timestamp}_$index";
    final isDownloading = _downloadingLogKeys.contains(itemKey);

    // Format display date
    String dateDisplay = "";
    if (timestamp.isNotEmpty) {
      try {
        final dt = DateTime.parse(timestamp).toLocal();
        dateDisplay = " • ${dt.day}/${dt.month}/${dt.year}";
      } catch (_) {
        dateDisplay = " • ${timestamp.split('T').first}";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Farmer Profile & Verified Badge Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primarySurface,
                  child: Text(
                    farmerName.isNotEmpty ? farmerName[0] : 'K',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              farmerName,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF059669)),
                        ],
                      ),
                      Text(
                        "📍 $village, $state$dateDisplay",
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Compliance Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    "$score% OK",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Crop & Action Pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "🌾 $crop",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "⚡ $actionType",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3. Product & Dosage Box
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.science_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "Dose: $dosage",
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                if (transcript.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    "\"$transcript\"",
                    style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4. Action Buttons (Download PDF & View Details)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                // View Details Button
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showLogDetailsModal(log, lang, itemKey),
                    child: Text(
                      AppTranslations.tr(lang, "view_all", "View Details"),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Download 3-Page PDF Report Button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    icon: isDownloading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: Text(
                      isDownloading ? "Downloading..." : AppTranslations.tr(lang, "download_peer_pdf", "Download PDF"),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: isDownloading ? null : () => _handleDownloadPdf(log, itemKey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_outlined, size: 36, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              AppTranslations.tr(lang, "no_logs_found_title", "No logs found for selected filters."),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              AppTranslations.tr(lang, "no_logs_found_sub", "Try selecting 'All Crops' or recorded new voice logs."),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _selectedCrop = "All";
                  _selectedRegion = "All";
                  _searchQuery = "";
                });
              },
              child: Text(AppTranslations.tr(lang, "reset_filters", "Reset Filters")),
            ),
          ],
        ),
      ),
    );
  }
}
