import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/farm_provider.dart';
import '../core/providers/evidence_provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/localization/app_translations.dart';
import '../widgets/custom_bottom_nav.dart';
import '../../models/product_model.dart';

class ScanProductScreen extends StatefulWidget {
  const ScanProductScreen({super.key});

  @override
  State<ScanProductScreen> createState() => _ScanProductScreenState();
}

class _ScanProductScreenState extends State<ScanProductScreen> {
  bool _isScanning = false;

  void _simulateScan(ProductInput product) async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() => _isScanning = false);
      _showVerifiedProductModal(product);
    }
  }

  void _saveProductEvidence(ProductInput prod) async {
    final evProv = Provider.of<EvidenceProvider>(context, listen: false);

    await evProv.addEvidence(
      title: "Input Verified: ${prod.name}",
      description:
          "Scanned QR ${prod.qrCode}. Batch ${prod.verifiedBatchNo} verified authentic with ${prod.manufacturer}.",
      evidenceType: 'PRODUCT_SCAN',
      productQr: prod.qrCode,
      productName: prod.name,
      dosagePerAcre: prod.recommendedDose,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text("${prod.name} verified & linked to Evidence Chain!"),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
        ),
      );
    }
  }

  void _showVerifiedProductModal(ProductInput prod) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final lang = auth.selectedLanguage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF047857),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppTranslations.tr(lang, "genuine_verified", "GENUINE BATCH VERIFIED"),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Text(
                    prod.toxicityBand,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildDetailRow(AppTranslations.tr(lang, "product_name_lbl", "Product Name"), prod.name),
            _buildDetailRow(AppTranslations.tr(lang, "manufacturer_lbl", "Manufacturer"), prod.manufacturer),
            _buildDetailRow(AppTranslations.tr(lang, "active_ing_lbl", "Active Ingredient"), prod.activeIngredient),
            _buildDetailRow(AppTranslations.tr(lang, "batch_no_lbl", "Batch Number"), prod.verifiedBatchNo),
            _buildDetailRow(AppTranslations.tr(lang, "recommended_dose_lbl", "Recommended Dose"), prod.recommendedDose),
            _buildDetailRow(
              AppTranslations.tr(lang, "phi_lbl", "Safe Pre-Harvest Interval (PHI)"),
              "${prod.preHarvestIntervalDays} Days",
            ),
            _buildDetailRow(AppTranslations.tr(lang, "expiry_date_lbl", "Expiry Date"), prod.expiryDate),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveProductEvidence(prod);
                },
                icon: const Icon(Icons.add_task_rounded, size: 20),
                label: Text(
                  AppTranslations.tr(lang, "link_product_btn", "LINK PRODUCT TO FIELD EVIDENCE"),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final farmProv = Provider.of<FarmProvider>(context);
    final products = farmProv.products;

    final agrochemicalProd = products.isNotEmpty ? products.first : ProductInput(
      name: "Tilt 25% EC (Propiconazole)",
      category: "Fungicide",
      manufacturer: "Syngenta India Ltd.",
      activeIngredient: "Propiconazole 25% EC",
      toxicityBand: "Blue Band (Moderate)",
      qrCode: "PRAMAAN-CHEM-2026-SYNG-01",
      barcode: "8901234567890",
      recommendedDose: "200 ml / Acre",
      targetPests: ["Rust", "Blight"],
      preHarvestIntervalDays: 30,
      verifiedBatchNo: "SYN-2026-8891",
      expiryDate: "Dec 2027",
      genuineVerified: true,
    );

    final seedProd = products.length > 1 ? products[1] : ProductInput(
      name: "Pioneer Cotton Seeds",
      category: "Seeds",
      manufacturer: "Corteva Agriscience",
      activeIngredient: "Bt-II Hybrid BG-II",
      toxicityBand: "Green Band (Safe)",
      qrCode: "PRAMAAN-SEED-2026-COR-02",
      barcode: "8909876543210",
      recommendedDose: "2 Packets / Acre",
      targetPests: ["Bollworm"],
      preHarvestIntervalDays: 0,
      verifiedBatchNo: "A23B7",
      expiryDate: "Nov 2026",
      genuineVerified: true,
    );

    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppTranslations.tr(lang, "scan_bottle_title", "Scan Input Bottle / Seed QR"),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16.5,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scanner Viewport Box with Lush Leaves Background & QR Target
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: NetworkImage(
                    "https://images.unsplash.com/photo-1530836369250-ef72a3f5cda8?w=800&auto=format&fit=crop&q=80",
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black.withValues(alpha: 0.35),
                ),
                child: Stack(
                  children: [
                    // Corner bracket target frame
                    Center(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.qr_code_2_rounded,
                              size: 70,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_isScanning)
                      const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF10B981),
                          strokeWidth: 3.5,
                        ),
                      ),
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Align QR / Barcode within frame",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Scan to verify info card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Color(0xFF047857),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Scan to verify product authenticity,",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "check expiry date and get usage guidelines.",
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Section: Select Bottle / Package to Scan
            const Text(
              "Select Bottle / Package to Scan",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryCard(
                    title: "Agrochemical\nBottle",
                    subtitle: "Scan pesticide /\nfertilizer bottle",
                    icon: Icons.science_rounded,
                    onTap: () => _simulateScan(agrochemicalProd),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCategoryCard(
                    title: "Seed Package",
                    subtitle: "Scan seed bag\nor packet",
                    icon: Icons.eco_rounded,
                    onTap: () => _simulateScan(seedProd),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Pramaan Verified Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF047857),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Pramaan Verified",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Only verified and registered products are supported for scanning.",
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recent Scans Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Scans",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/evidence_review'),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      "View All",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Recent Scans List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildScanHistoryItem(
                    title: "Tilt 25% EC (Propiconazole)",
                    subtitle: "Verified • Valid till Dec 2027",
                    time: "Today, 8:30 AM",
                    icon: Icons.science_rounded,
                    onTap: () => _showVerifiedProductModal(agrochemicalProd),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFF1F5F9)),
                  _buildScanHistoryItem(
                    title: "Pioneer Cotton Seeds",
                    subtitle: "Verified • Batch A23B7",
                    time: "Yesterday, 5:12 PM",
                    icon: Icons.eco_rounded,
                    onTap: () => _showVerifiedProductModal(seedProd),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(
        currentIndex: -1,
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF047857),
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        height: 1.2,
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanHistoryItem({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFF047857),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              time,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF047857),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
