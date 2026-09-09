import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/farm_provider.dart';
import '../core/localization/app_translations.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final lang = auth.selectedLanguage;
    final nameCtrl = TextEditingController(text: auth.userName.isNotEmpty ? auth.userName : "Anushka");
    final villageCtrl = TextEditingController(text: auth.userVillage.isNotEmpty ? auth.userVillage : "Nashik, Maharashtra");
    final phoneCtrl = TextEditingController(text: auth.userPhone.isNotEmpty ? auth.userPhone : "9876543210");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppTranslations.tr(lang, "edit_farmer_profile", "Edit Farmer Profile"),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: AppTranslations.tr(lang, "full_name_lbl", "Full Name"),
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: villageCtrl,
              decoration: InputDecoration(
                labelText: AppTranslations.tr(lang, "village_location_lbl", "Village / Location"),
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: AppTranslations.tr(lang, "phone_number_lbl", "Phone Number"),
                prefixIcon: const Icon(Icons.phone_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppTranslations.tr(lang, "cancel_btn", "Cancel")),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              auth.updateFarmerProfile(
                name: nameCtrl.text.trim(),
                village: villageCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppTranslations.tr(lang, "profile_updated_success", "✓ Profile updated successfully!")),
                  backgroundColor: const Color(0xFF047857),
                ),
              );
            },
            child: Text(AppTranslations.tr(lang, "save_btn", "Save")),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final farmProv = Provider.of<FarmProvider>(context);
    final farm = farmProv.selectedFarm;
    final lang = auth.selectedLanguage;

    final displayName = auth.userName.isNotEmpty ? auth.userName : "Anushka";
    final initialLetter = displayName.isNotEmpty ? displayName[0].toUpperCase() : "A";
    final locationText = auth.userVillage.isNotEmpty ? auth.userVillage : "Nashik, Maharashtra";
    final farmName = farm?.name.isNotEmpty == true ? farm!.name : "Sahyadri Bio-Farms (Plot North)";
    final totalAcres = farm?.totalAcres != null ? "${farm!.totalAcres} ${AppTranslations.tr(lang, "acres_unit", "Acre")}" : "12.5 ${AppTranslations.tr(lang, "acres_unit", "Acre")}";
    final activeCrop = auth.activeCrop.isNotEmpty ? auth.activeCrop : "Cotton (Bt-III)";
    final compliance = farm?.complianceScore != null ? "${farm!.complianceScore}% (Grade A+)" : "96.4% (Grade A+)";
    final coords = "${farm?.latitude ?? 20.1985}° N, ${farm?.longitude ?? 73.8322}° E";

    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 22),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/farmer_dashboard');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.tr(lang, "user_profile_title", "User Profile"),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              AppTranslations.tr(lang, "user_profile_sub", "Your details and farm information"),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Profile Hero Banner Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD1FAE5), width: 1.2),
              ),
              child: Stack(
                children: [
                  // Farmland landscape illustration in bottom right
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: 0.5,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Icon(Icons.forest_rounded, size: 28, color: Color(0xFF10B981)),
                          Icon(Icons.home_work_rounded, size: 36, color: Color(0xFF059669)),
                          Icon(Icons.park_rounded, size: 24, color: Color(0xFF34D399)),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar Initial Circle
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD1FAE5),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initialLetter,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Name, Role & Location
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppTranslations.tr(lang, "role_farmer", "Farmer / Grower"),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF047857),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF64748B)),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      locationText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Edit Button Pill
                        InkWell(
                          onTap: () => _showEditProfileDialog(context, auth),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_outlined, size: 13, color: Color(0xFF0F172A)),
                                const SizedBox(width: 4),
                                Text(
                                  AppTranslations.tr(lang, "edit_name", "Edit"),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Farm Details Section Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.spa_rounded, color: Color(0xFF047857), size: 22),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.tr(lang, "farm_details_title", "Farm Details"),
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      AppTranslations.tr(lang, "user_profile_sub", "Your registered farm information"),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/field_map'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.location_on_rounded, color: Color(0xFF047857), size: 14),
                        SizedBox(width: 4),
                        Text(
                          "Map",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Farm Parameters Card Container
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildFarmRow(
                    icon: Icons.home_rounded,
                    label: AppTranslations.tr(lang, "plot_label", "Farm Name"),
                    value: farmName,
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildFarmRow(
                    icon: Icons.terrain_rounded,
                    label: AppTranslations.tr(lang, "area_label", "Total Area"),
                    value: totalAcres,
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildFarmRow(
                    icon: Icons.eco_rounded,
                    label: AppTranslations.tr(lang, "crop_label", "Primary Active Crop"),
                    value: activeCrop,
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildFarmRow(
                    icon: Icons.shield_rounded,
                    label: AppTranslations.tr(lang, "compliance_label", "Compliance Score"),
                    value: compliance,
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildFarmRow(
                    icon: Icons.location_on_rounded,
                    label: AppTranslations.tr(lang, "village_location_lbl", "Location Coordinates"),
                    value: coords,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Account Type Verified Farmer Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD1FAE5), width: 1.2),
              ),
              child: Row(
                children: [
                  // Left side: Document icon & Verified Farmer
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(Icons.description_rounded, color: Color(0xFF047857), size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppTranslations.tr(lang, "role_farmer", "Account Type"),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppTranslations.tr(lang, "farmer_verified_log", "Verified Farmer"),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF047857),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                        ],
                      ),
                    ],
                  ),

                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 1.2,
                    height: 30,
                    color: const Color(0xFFD1FAE5),
                  ),

                  // Right side: Slogan & Leaf
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppTranslations.tr(lang, "sustainable_slogan", "Helping build sustainable agriculture"),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.eco_rounded, color: Color(0xFFA7F3D0), size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Big Switch Role / Persona Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF064E3B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: () => Navigator.pushNamed(context, '/profile_selection'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sync_alt_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppTranslations.tr(lang, "switch_role_menu", "Switch Role / Persona"),
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: const Color(0xFF047857), size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF94A3B8),
            size: 18,
          ),
        ],
      ),
    );
  }
}
