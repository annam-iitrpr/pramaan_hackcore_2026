import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/localization/app_translations.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;

    final notifs = [
      {
        "title": AppTranslations.tr(lang, "notif_spray_title", "Spray Window Alert: Clear Skies Next 6 Hours"),
        "message": AppTranslations.tr(lang, "notif_spray_msg", "Wind speed 5.4 km/h, humidity 64%. Optimal window for foliar nutrient sprays in Dindori."),
        "type": lang == 'hi' ? "मौसम" : (lang == 'mr' ? "हवामान" : "WEATHER"),
        "timestamp": lang == 'hi' ? "१० मि. पहले" : (lang == 'mr' ? "१० मि. पूर्वी" : "10 mins ago"),
        "icon": Icons.wb_sunny_rounded,
        "color": AppColors.accentGold,
      },
      {
        "title": AppTranslations.tr(lang, "notif_verif_title", "Evidence EV-2026-8812 Cryptographically Verified"),
        "message": AppTranslations.tr(lang, "notif_verif_msg", "Field Agent approved Post-Treatment Efficacy record. Blockchain anchor SHA-256 updated."),
        "type": lang == 'hi' ? "सत्यापन" : (lang == 'mr' ? "प्रमाणन" : "VERIFICATION"),
        "icon": Icons.verified_user_rounded,
        "color": AppColors.primary,
        "timestamp": lang == 'hi' ? "१ घंटे पहले" : (lang == 'mr' ? "१ तासापूर्वी" : "1 hour ago"),
      },
      {
        "title": AppTranslations.tr(lang, "notif_buyer_title", "Buyer Quote Request: ITC Agri-Business"),
        "message": AppTranslations.tr(lang, "notif_buyer_msg", "ITC Agri offered ₹7,850/Qtl (+₹450 Pramaan Organic Verified Premium) for Lot #CT-881."),
        "type": lang == 'hi' ? "खरीदार" : (lang == 'mr' ? "खरेदीदार" : "BUYER"),
        "icon": Icons.storefront_rounded,
        "color": AppColors.primaryDark,
        "timestamp": lang == 'hi' ? "३ घंटे पहले" : (lang == 'mr' ? "३ तासांपूर्वी" : "3 hours ago"),
      },
      {
        "title": AppTranslations.tr(lang, "notif_pest_title", "Regional Pest Outbreak Warning: Pink Bollworm"),
        "message": AppTranslations.tr(lang, "notif_pest_msg", "Neighbouring plots reported light moth trap activity. Check pheromone traps daily."),
        "type": lang == 'hi' ? "कीट चेतावनी" : (lang == 'mr' ? "कीड इशारा" : "PEST_ALERT"),
        "icon": Icons.bug_report_rounded,
        "color": AppColors.flaggedRed,
        "timestamp": lang == 'hi' ? "१ दिन पहले" : (lang == 'mr' ? "१ दिवसापूर्वी" : "1 day ago"),
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          AppTranslations.tr(lang, "notifications_title", "System Alerts & Notifications"),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifs.length,
        itemBuilder: (context, index) {
          final n = notifs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (n['color'] as Color).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      n['icon'] as IconData,
                      color: n['color'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              n['type'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: n['color'] as Color,
                              ),
                            ),
                            Text(
                              n['timestamp'] as String,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n['title'] as String,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n['message'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
