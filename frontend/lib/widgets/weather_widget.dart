import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/localization/app_translations.dart';
import '../../models/weather_model.dart';

class WeatherSummaryWidget extends StatelessWidget {
  final WeatherAdvisory? advisory;
  final VoidCallback onTap;

  const WeatherSummaryWidget({
    super.key,
    required this.advisory,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;
    final weather = advisory?.currentWeather;
    final temp = weather?.temperatureC ?? 28.5;
    final location = weather?.districtName ?? "Ludhiana";
    final wind = weather?.windSpeedKmh ?? 5.4;
    final deltaT = weather?.deltaTC ?? 3.6;

    final isOptimal = wind <= 14.0 && deltaT >= 2.0 && deltaT <= 8.5 && temp <= 33.0;
    final isCaution = !isOptimal && (wind <= 18.0 || temp <= 35.0);

    Color bgStart = isOptimal ? const Color(0xFF064E3B) : (isCaution ? const Color(0xFF78350F) : const Color(0xFF7F1D1D));
    Color bgEnd = isOptimal ? const Color(0xFF047857) : (isCaution ? const Color(0xFFB45309) : const Color(0xFF991B1B));

    String badgeLabel = isOptimal
        ? AppTranslations.tr(lang, "spray_safe_badge")
        : (isCaution ? AppTranslations.tr(lang, "spray_caution_badge") : AppTranslations.tr(lang, "spray_no_badge"));

    String mainDesc = isOptimal
        ? AppTranslations.tr(lang, "safe_to_spray_sub")
        : (isCaution ? AppTranslations.tr(lang, "spray_caution_sub") : AppTranslations.tr(lang, "do_not_spray_sub"));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [bgStart, bgEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: bgStart.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Location & Live Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: Color(0xFF34D399), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "$location, Punjab",
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFA7F3D0),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        AppTranslations.tr(lang, "live_weather"),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Middle Row: Temperature & Spray Decision
            Row(
              children: [
                Text(
                  "$temp°C",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOptimal ? AppTranslations.tr(lang, "safe_to_spray") : AppTranslations.tr(lang, "spray_caution"),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "💨 ${AppTranslations.tr(lang, "wind")}: $wind km/h • 💧 ${AppTranslations.tr(lang, "rain_risk")}: ${weather?.precipitationProb ?? 0}% • 🌿 ${AppTranslations.tr(lang, "absorption")}: ${isOptimal ? AppTranslations.tr(lang, "pleasant") : AppTranslations.tr(lang, "moderate")}",
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFFA7F3D0)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Recommendation
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF34D399), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mainDesc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
