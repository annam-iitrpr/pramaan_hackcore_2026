import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/localization/app_translations.dart';

class ProfileSelectionScreen extends StatelessWidget {
  const ProfileSelectionScreen({super.key});

  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'hi':
        return 'हिन्दी';
      case 'mr':
        return 'मराठी';
      case 'pa':
        return 'ਪੰਜਾਬੀ';
      case 'en':
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Bar / Back Navigation & Language Switcher
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 16, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 24),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  // Language Selector Pill
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => AppTranslations.showLanguageSelectorModal(
                        context,
                        auth.selectedLanguage,
                        (newLang) => auth.setLanguage(newLang),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF166534).withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.language_rounded, size: 17, color: Color(0xFF166534)),
                            const SizedBox(width: 6),
                            Text(
                              _getLanguageDisplayName(auth.selectedLanguage),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF166534),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF166534)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                AppTranslations.tr(lang, "choose_role_title", "Choose Your Role"),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3 Role Selection Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Role 1: Farmer / Grower
                  _buildRoleCard(
                    title: AppTranslations.tr(lang, "role_farmer", "Farmer / Grower"),
                    icon: Icons.agriculture_rounded,
                    isSelected: auth.currentRole == UserRoleType.farmer,
                    hasHighlightBorder: true,
                    onTap: () {
                      auth.switchRole(UserRoleType.farmer);
                      Navigator.pushReplacementNamed(context, '/farmer_auth');
                    },
                  ),
                  const SizedBox(height: 16),

                  // Role 2: Field Agent / Agronomist
                  _buildRoleCard(
                    title: AppTranslations.tr(lang, "role_field_agent", "Field Agent / Agronomist"),
                    icon: Icons.person_rounded,
                    isSelected: auth.currentRole == UserRoleType.fieldAgent,
                    hasHighlightBorder: false,
                    onTap: () {
                      auth.switchRole(UserRoleType.fieldAgent);
                      Navigator.pushReplacementNamed(context, '/field_agent_dashboard');
                    },
                  ),
                  const SizedBox(height: 16),

                  // Role 3: Buyer / Agri-Input Partner
                  _buildRoleCard(
                    title: AppTranslations.tr(lang, "role_buyer", "Buyer / Agri-Input Partner"),
                    icon: Icons.storefront_rounded,
                    isSelected: auth.currentRole == UserRoleType.buyer,
                    hasHighlightBorder: false,
                    onTap: () {
                      auth.switchRole(UserRoleType.buyer);
                      Navigator.pushReplacementNamed(context, '/buyer_pricing');
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Bottom Illustrated Rolling Green Hills & Leaves with "Better Farming Together"
            _buildBottomHillsIllustration(lang),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool hasHighlightBorder,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasHighlightBorder ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
          width: hasHighlightBorder ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Soft green circular icon container
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD1FAE5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(icon, color: const Color(0xFF047857), size: 30),
                  ),
                ),
                const SizedBox(width: 16),

                // Role Title
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),

                // Chevron Right
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF047857),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomHillsIllustration(String lang) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Rolling Hills Background
          CustomPaint(
            size: const Size(double.infinity, 140),
            painter: _RollingHillsPainter(),
          ),

          // Left Leaves Sprout
          Positioned(
            left: 20,
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform.rotate(
                  angle: -0.4,
                  child: const Icon(Icons.eco_rounded, size: 36, color: Color(0xFF10B981)),
                ),
                Transform.rotate(
                  angle: 0.3,
                  child: const Icon(Icons.eco_rounded, size: 28, color: Color(0xFF34D399)),
                ),
              ],
            ),
          ),

          // Right Leaves Sprout
          Positioned(
            right: 20,
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform.rotate(
                  angle: -0.3,
                  child: const Icon(Icons.eco_rounded, size: 28, color: Color(0xFF34D399)),
                ),
                Transform.rotate(
                  angle: 0.4,
                  child: const Icon(Icons.eco_rounded, size: 36, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),

          // Centered "Better Farming Together" & Underline Bar
          Positioned(
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppTranslations.tr(lang, "better_farming_together", "Better Farming\nTogether"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 28,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF047857),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),

          // Home Bottom Indicator bar
          Positioned(
            bottom: 6,
            child: Container(
              width: 120,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RollingHillsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Back Hill (lightest green)
    final backHillPaint = Paint()
      ..color = const Color(0xFFECFDF5).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final backPath = Path();
    backPath.moveTo(0, size.height * 0.4);
    backPath.quadraticBezierTo(
      size.width * 0.35, size.height * 0.15,
      size.width * 0.7, size.height * 0.35,
    );
    backPath.quadraticBezierTo(
      size.width * 0.85, size.height * 0.45,
      size.width, size.height * 0.3,
    );
    backPath.lineTo(size.width, size.height);
    backPath.lineTo(0, size.height);
    backPath.close();
    canvas.drawPath(backPath, backHillPaint);

    // Front Hill (soft mint green)
    final frontHillPaint = Paint()
      ..color = const Color(0xFFD1FAE5).withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final frontPath = Path();
    frontPath.moveTo(0, size.height * 0.6);
    frontPath.quadraticBezierTo(
      size.width * 0.25, size.height * 0.45,
      size.width * 0.5, size.height * 0.55,
    );
    frontPath.quadraticBezierTo(
      size.width * 0.8, size.height * 0.65,
      size.width, size.height * 0.5,
    );
    frontPath.lineTo(size.width, size.height);
    frontPath.lineTo(0, size.height);
    frontPath.close();
    canvas.drawPath(frontPath, frontHillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
