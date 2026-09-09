import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/localization/app_translations.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  void _handleNavigation(BuildContext context, int index) {
    if (onTap != null) {
      onTap!(index);
      return;
    }

    if (index == currentIndex) return;

    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/farmer_dashboard',
          (route) => false,
        );
        break;
      case 1:
        Navigator.pushNamed(context, '/voice_log');
        break;
      case 2:
        Navigator.pushNamed(context, '/community_logs');
        break;
      case 3:
        Navigator.pushNamed(context, '/ask_pramaan');
        break;
    }
  }

  void _showQuickAddSheet(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final lang = auth.selectedLanguage;

    showModalBottomSheet(
      context: context,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppTranslations.tr(lang, "quick_record_title", "Quick Record Field Evidence"),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded, color: Color(0xFF047857)),
              ),
              title: Text(AppTranslations.tr(lang, "voice_log", "Voice Log"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(AppTranslations.tr(lang, "voice_log_sheet_sub", "Speak & record your field activity in your language"), style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/voice_log');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF047857)),
              ),
              title: Text(AppTranslations.tr(lang, "crop_camera_title", "Crop Camera"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(AppTranslations.tr(lang, "crop_cam_sheet_sub", "Diagnose leaf disease & get instant prescriptions"), style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/crop_camera');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF047857)),
              ),
              title: Text(AppTranslations.tr(lang, "scan_bottle_title", "Scan Bottle"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(AppTranslations.tr(lang, "scan_sheet_sub", "Verify pesticide authenticity and batch QR"), style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/scan_product');
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.science_rounded, color: Color(0xFF047857)),
              ),
              title: Text(AppTranslations.tr(lang, "new_spray_title", "New Spray Log"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text(AppTranslations.tr(lang, "spray_sheet_sub", "Record dosage, water volume and safe PHI"), style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/new_application');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, Icons.home_rounded, AppTranslations.tr(lang, "home", "Home")),
              _buildNavItem(context, 1, Icons.mic_rounded, AppTranslations.tr(lang, "voice_log", "Voice Log")),
              _buildCenterActionButton(context),
              _buildNavItem(context, 2, Icons.groups_rounded, AppTranslations.tr(lang, "community", "Community")),
              _buildNavItem(context, 3, Icons.chat_bubble_outline_rounded, AppTranslations.tr(lang, "ask_ai", "Ask AI")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    const selectedColor = Color(0xFF047857);
    const unselectedColor = Color(0xFF64748B);

    return InkWell(
      onTap: () => _handleNavigation(context, index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? selectedColor : unselectedColor,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? selectedColor : unselectedColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterActionButton(BuildContext context) {
    return InkWell(
      onTap: () => _showQuickAddSheet(context),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF047857),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF047857).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
