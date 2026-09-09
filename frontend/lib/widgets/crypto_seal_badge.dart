import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';

class CryptoSealBadge extends StatelessWidget {
  final double score;
  final String status;
  final bool compact;
  final String? language;

  const CryptoSealBadge({
    super.key,
    required this.score,
    required this.status,
    this.compact = false,
    this.language,
  });

  String _localizedStatus(String lang, String status) {
    if (status == 'VERIFIED') {
      if (lang == 'hi') return 'सत्यापित';
      if (lang == 'mr') return 'प्रमाणित';
      if (lang == 'pa') return 'ਤਸਦੀਕ';
      return 'VERIFIED';
    } else if (status == 'PENDING') {
      if (lang == 'hi') return 'प्रतीक्षारत';
      if (lang == 'mr') return 'प्रलंबित';
      if (lang == 'pa') return 'ਬਕਾਇਆ';
      return 'PENDING';
    } else {
      if (lang == 'hi') return 'जांच आवश्यक';
      if (lang == 'mr') return 'तपासणी आवश्यक';
      if (lang == 'pa') return 'ਜਾਂਚ ਲੋੜੀਂਦੀ';
      return 'REVIEW';
    }
  }

  @override
  Widget build(BuildContext context) {
    String lang = language ?? 'en';
    try {
      final auth = Provider.of<AuthProvider>(context);
      lang = language ?? auth.selectedLanguage;
    } catch (_) {}

    Color bg;
    Color fg;
    IconData icon;

    if (status == 'VERIFIED') {
      bg = AppColors.primarySurface;
      fg = AppColors.primaryDark;
      icon = Icons.verified_rounded;
    } else if (status == 'PENDING') {
      bg = AppColors.goldLight;
      fg = AppColors.accentAmber;
      icon = Icons.hourglass_top_rounded;
    } else {
      bg = const Color(0xFFFEE2E2);
      fg = AppColors.flaggedRed;
      icon = Icons.warning_amber_rounded;
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              "$score%",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            "${_localizedStatus(lang, status)} ($score%)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

