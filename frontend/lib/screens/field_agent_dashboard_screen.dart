import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/farm_provider.dart';
import '../core/providers/evidence_provider.dart';
import '../widgets/evidence_card.dart';

class FieldAgentDashboardScreen extends StatelessWidget {
  const FieldAgentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final farmProv = Provider.of<FarmProvider>(context);
    final evProv = Provider.of<EvidenceProvider>(context);

    final pendingItems = evProv.allEvidence.where((e) => e.verificationStatus == 'PENDING').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "FIELD AGENT / AGRONOMY PORTAL",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: AppColors.primary),
            ),
            Text(
              auth.userName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined, color: AppColors.textPrimary),
            tooltip: "Field Geospatial Map",
            onPressed: () => Navigator.pushNamed(context, '/field_map'),
          ),
          IconButton(
            icon: const Icon(Icons.model_training_rounded, color: AppColors.textPrimary),
            tooltip: "Learning Loop",
            onPressed: () => Navigator.pushNamed(context, '/learning_loop'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'switch') Navigator.pushNamed(context, '/profile_selection');
              if (val == 'agronomy') Navigator.pushNamed(context, '/agronomy_suite');
              if (val == 'efficacy') Navigator.pushNamed(context, '/efficacy_insights');
              if (val == 'reports') Navigator.pushNamed(context, '/evidence_report');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'agronomy', child: Text("Agronomy Suite")),
              const PopupMenuItem(value: 'efficacy', child: Text("Efficacy Insights")),
              const PopupMenuItem(value: 'reports', child: Text("Audit Reports")),
              const PopupMenuItem(value: 'switch', child: Text("Switch Role")),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI Stat Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: "Managed Farms",
                    value: "${farmProv.farms.length}",
                    sub: "12 Plots Active",
                    icon: Icons.terrain_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: "Pending Queue",
                    value: "${pendingItems.length}",
                    sub: "Action Required",
                    icon: Icons.pending_actions_rounded,
                    color: AppColors.accentGold,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    title: "Avg Compliance",
                    value: "95.8%",
                    sub: "Grade A+",
                    icon: Icons.verified_rounded,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // High Priority Alert Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.flaggedRed, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Pest Alert: Early Whitefly in Plot North-04",
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.flaggedRed),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Post-spray recovery check validated 86.4% mortality with Bio-Neem Power.",
                          style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/efficacy_insights'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.flaggedRed,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    child: const Text("REVIEW", style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Farm Plots List Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Assigned Farm Plots",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/field_map'),
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: const Text("Map View"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...farmProv.farms.map((f) => _buildFarmPlotCard(context, f, farmProv)),
            const SizedBox(height: 20),

            // Pending Evidence Sign-off Queue
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pending Verification Queue",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/evidence_review'),
                  child: const Text("Full Queue"),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (pendingItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 36),
                    SizedBox(height: 6),
                    Text("All Evidence Logs Verified!", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                    Text("No pending logs awaiting agronomist review.", style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              )
            else
              ...pendingItems.map((item) => EvidenceCard(
                    item: item,
                    onTap: () => Navigator.pushNamed(context, '/evidence_detail', arguments: item),
                  )),

            const SizedBox(height: 24),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text("LOG OBSERVATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.pushNamed(context, '/new_observation'),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
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
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text(sub, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildFarmPlotCard(BuildContext context, dynamic farm, FarmProvider prov) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySurface,
          child: const Icon(Icons.eco_rounded, color: AppColors.primary),
        ),
        title: Text(farm.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
        subtitle: Text("Grower: ${farm.owner} • ${farm.activeCrop} (${farm.totalAcres} Ac)", style: const TextStyle(fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("${farm.complianceScore}%", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 13)),
            const Text("Compliance", style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
        onTap: () {
          prov.selectFarm(farm);
          Navigator.pushNamed(context, '/farmer_dashboard');
        },
      ),
    );
  }
}
