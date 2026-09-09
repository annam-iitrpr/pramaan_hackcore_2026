import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/farm_provider.dart';
import '../core/localization/app_translations.dart';

class SeasonJournalScreen extends StatelessWidget {
  const SeasonJournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final farmProv = Provider.of<FarmProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final farm = farmProv.selectedFarm;
    final lang = auth.selectedLanguage;

    final milestones = [
      {
        "date": "15 Jun 2026",
        "stage": lang == 'hi' ? "बुवाई अवस्था" : (lang == 'mr' ? "पेरणी अवस्था" : "Land Prep & Sowing"),
        "title": AppTranslations.tr(lang, "sowing_milestone_title", "Certified Bt-II Seed Sowing & Trichoderma Soil Treatment"),
        "type": "SOWING",
        "status": AppTranslations.tr(lang, "completed_status", "COMPLETED"),
        "isDone": true,
        "notes": AppTranslations.tr(lang, "sowing_milestone_notes", "Treated seeds with Trichoderma Viride bio-fungicide before precision sowing."),
      },
      {
        "date": "05 Jul 2026",
        "stage": lang == 'hi' ? "अंकुरण अवस्था" : (lang == 'mr' ? "रोपे उगवण" : "Seedling Emergence"),
        "title": AppTranslations.tr(lang, "fert_milestone_title", "Basal Organic Manure + Micro-Nutrient Application"),
        "type": "FERTILIZER",
        "status": AppTranslations.tr(lang, "completed_status", "COMPLETED"),
        "isDone": true,
        "notes": AppTranslations.tr(lang, "fert_milestone_notes", "Applied 5 tons well-decomposed FYM and zinc sulphate foliar booster."),
      },
      {
        "date": "25 Aug 2026",
        "stage": lang == 'hi' ? "वानस्पतिक अवस्था" : (lang == 'mr' ? "शाकीय वाढ" : "Vegetative & Squaring"),
        "title": AppTranslations.tr(lang, "obs_milestone_title", "Whitefly Detection & AI Diagnosis"),
        "type": "OBSERVATION",
        "status": AppTranslations.tr(lang, "completed_status", "COMPLETED"),
        "isDone": true,
        "notes": AppTranslations.tr(lang, "obs_milestone_notes", "Pramaan Vision AI detected early whitefly; recommended botanical insecticide."),
      },
      {
        "date": "28 Aug 2026",
        "stage": lang == 'hi' ? "वानस्पतिक अवस्था" : (lang == 'mr' ? "शाकीय वाढ" : "Vegetative & Squaring"),
        "title": AppTranslations.tr(lang, "app_milestone_title", "Bio-Neem Spray Applied (Batch Verified)"),
        "type": "APPLICATION",
        "status": AppTranslations.tr(lang, "completed_status", "COMPLETED"),
        "isDone": true,
        "notes": AppTranslations.tr(lang, "app_milestone_notes", "QR scanned bottle BNP-2026-MAY-0441; 400ml/Acre applied during calm weather."),
      },
      {
        "date": "29 Aug 2026",
        "stage": lang == 'hi' ? "फूल अवस्था" : (lang == 'mr' ? "फुलोरा अवस्था" : "Flowering & Boll Formation"),
        "title": AppTranslations.tr(lang, "eff_milestone_title", "Efficacy Check: 86.4% Pest Reduction Verified"),
        "type": "EFFICACY_REVIEW",
        "status": AppTranslations.tr(lang, "completed_status", "COMPLETED"),
        "isDone": true,
        "notes": AppTranslations.tr(lang, "eff_milestone_notes", "NDVI vitality proxy restored to 0.79. Safe for upcoming flowering phase."),
      },
      {
        "date": "15 Oct 2026",
        "stage": lang == 'hi' ? "कटाई अवस्था" : (lang == 'mr' ? "काढणी अवस्था" : "Boll Bursting & Harvest"),
        "title": AppTranslations.tr(lang, "harv_milestone_title", "Target Harvest & Export Quality Batch Seal"),
        "type": "HARVEST_ESTIMATE",
        "status": AppTranslations.tr(lang, "upcoming_status", "UPCOMING"),
        "isDone": false,
        "notes": AppTranslations.tr(lang, "harv_milestone_notes", "Anticipated yield: 18.5 Quintals/Acre with Grade-A Purity Premium."),
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.tr(lang, "season_journal_timeline", "Season Journal & Timeline"),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (farm != null)
              Text(
                "${farm.activeCrop} • ${farm.village}",
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: milestones.length,
        itemBuilder: (context, index) {
          final m = milestones[index];
          final isCompleted = m['isDone'] == true;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline Column
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted ? AppColors.primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? AppColors.primary
                            : AppColors.textMuted,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  if (index < milestones.length - 1)
                    Container(
                      width: 2,
                      height: 100,
                      color: isCompleted
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : const Color(0xFFE2E8F0),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Milestone Card
              Expanded(
                child: Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              m['date'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? AppColors.primarySurface
                                    : AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                m['status'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isCompleted
                                      ? AppColors.primaryDark
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m['title'] as String,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${AppTranslations.tr(lang, "stage_label", "Stage:")} ${m['stage']}",
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.accentAmber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          m['notes'] as String,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
