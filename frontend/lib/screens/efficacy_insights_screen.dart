import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class EfficacyInsightsScreen extends StatelessWidget {
  const EfficacyInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Input Efficacy Analytics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Treatment Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TREATMENT TRIAL #TT-881", style: TextStyle(color: AppColors.primaryAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text("Day 4 Post-Spray", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text("Bio-Neem Power 10000 PPM (Foliar)", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  Text("Target: Whitefly Infestation on Cotton (Bt-II)", style: TextStyle(color: Color(0xFFA7F3D0), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Key Metrics Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricBox(
                    "Pest Mortality",
                    "86.4%",
                    "+14% vs Regional Avg",
                    Icons.bug_report_rounded,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricBox(
                    "Canopy Vitality",
                    "0.79 NDVI",
                    "+27.4% Chlorophyll",
                    Icons.energy_savings_leaf_rounded,
                    AppColors.accentGold,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricBox(
                    "Yield Gain Est.",
                    "₹4,850/Ac",
                    "ROI 6.2x",
                    Icons.trending_up_rounded,
                    AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Side-by-Side Visual Comparison
            const Text(
              "Pre vs. Post Application Visual Audit",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1530836369250-ef72a3f5cda8?w=600&auto=format&fit=crop&q=80',
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text("Day 0: Pre-Treatment", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Text("14-16 Nymphs/Leaf • High Stress", style: TextStyle(fontSize: 10.5, color: AppColors.flaggedRed)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1586771107445-d3ca888129ff?w=600&auto=format&fit=crop&q=80',
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text("Day 4: Post-Treatment", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const Text("1-2 Nymphs/Leaf • Clean Canopy", style: TextStyle(fontSize: 10.5, color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recovery Timeline Graph Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Pest Suppression Timeline (Days 0 to 7)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildTimelineBar("Day 0 (Pre-Spray)", 100, "16 Nymphs (Baseline)", AppColors.flaggedRed),
                  _buildTimelineBar("Day 2 (Post-Spray)", 45, "7 Nymphs (-55%)", AppColors.accentGold),
                  _buildTimelineBar("Day 4 (Verified)", 14, "2 Nymphs (-86%)", AppColors.primary),
                  _buildTimelineBar("Day 7 (Projected)", 6, "< 1 Nymph (-94%)", AppColors.primaryDark),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBox(String title, String val, String sub, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
          Text(sub, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildTimelineBar(String label, double percentage, String detail, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(detail, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100.0,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
