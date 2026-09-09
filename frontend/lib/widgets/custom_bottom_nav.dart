import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        Navigator.pushNamed(context, '/agri_store');
        break;
      case 2:
        Navigator.pushNamed(context, '/community_logs');
        break;
      case 3:
        Navigator.pushNamed(context, '/ask_pramaan');
        break;
      case 4: // Voice Log direct center action
        Navigator.pushNamed(context, '/voice_log');
        break;
    }
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
              _buildNavItem(context, 1, Icons.storefront_rounded, AppTranslations.tr(lang, "store", "Store")),
              _buildCenterVoiceButton(context),
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

  Widget _buildCenterVoiceButton(BuildContext context) {
    final isSelected = currentIndex == 4;
    return InkWell(
      onTap: () {
        if (currentIndex != 4) {
          Navigator.pushNamed(context, '/voice_log');
        }
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF047857),
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: const Color(0xFF6EE7B7), width: 2.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF047857).withValues(alpha: isSelected ? 0.55 : 0.38),
              blurRadius: isSelected ? 12 : 10,
              spreadRadius: isSelected ? 1.5 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.mic_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
