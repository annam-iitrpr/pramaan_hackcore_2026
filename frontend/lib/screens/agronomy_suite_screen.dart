import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/farm_provider.dart';
import '../core/localization/app_translations.dart';

class AgronomySuiteScreen extends StatelessWidget {
  const AgronomySuiteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final farmProv = Provider.of<FarmProvider>(context);
    final lang = auth.selectedLanguage;
    final advisory = farmProv.weatherAdvisory;
    final weather = advisory?.currentWeather;
    final selectedDistrict = farmProv.selectedDistrict;
    final districts = farmProv.punjabDistricts;

    final tempVal = weather != null ? weather.temperatureC.toStringAsFixed(1) : "34.2";
    final humidityVal = weather != null ? "${weather.humidityPercent.toStringAsFixed(0)}%" : "72%";
    final windVal = weather != null ? "${weather.windSpeedKmh.toStringAsFixed(1)} km/h" : "2.2 km/h";
    final rainVal = weather != null ? "${weather.precipitationProb.toStringAsFixed(0)}%" : "18%";
    final districtName = selectedDistrict?.name ?? weather?.districtName ?? "Amritsar, Punjab";
    final fullLocation = districtName.contains("Punjab") ? districtName : "$districtName, Punjab";

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
              AppTranslations.tr(lang, "weather_guide", "Farmer Weather Advisory"),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              AppTranslations.tr(lang, "live_weather", "Weather insights for better farming"),
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Language selector dropdown pill: [ 🌐 EN v ]
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: () => AppTranslations.showLanguageSelectorModal(
                context,
                lang,
                (newLang) => auth.setLanguage(newLang),
              ),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language_rounded, color: Color(0xFF047857), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      lang.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Bar: [ 📍 Amritsar, Punjab              Change District > ]
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF047857),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      fullLocation,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _showDistrictPicker(context, farmProv, districts, selectedDistrict?.name),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppTranslations.tr(lang, "select_district", "Change District"),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B), size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Caution Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Stylized Sun with Rays Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.wb_sunny_rounded,
                        color: Color(0xFFD97706),
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Thin vertical divider line
                  Container(
                    width: 1.5,
                    height: 40,
                    color: const Color(0xFFFCD34D),
                  ),
                  const SizedBox(width: 12),
                  // Advice text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.tr(lang, "spray_caution", "Spray with Caution"),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          AppTranslations.tr(lang, "spray_caution_sub", "It is hot. Spray in early morning or evening for better results."),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF78350F),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Current Weather Section Header
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 18),
                const SizedBox(width: 6),
                Text(
                  AppTranslations.tr(lang, "live_weather", "Current Weather"),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2x2 Weather Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.thermostat_rounded,
                    iconBg: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF047857),
                    label: AppTranslations.tr(lang, "temp", "Temperature"),
                    value: "$tempVal°C",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.water_drop_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF2563EB),
                    label: AppTranslations.tr(lang, "heat_sun", "Humidity"),
                    value: humidityVal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.air_rounded,
                    iconBg: const Color(0xFFECFDF5),
                    iconColor: const Color(0xFF047857),
                    label: AppTranslations.tr(lang, "wind_speed", "Wind Speed"),
                    value: windVal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricCard(
                    icon: Icons.cloudy_snowing,
                    iconBg: const Color(0xFFF1F5F9),
                    iconColor: const Color(0xFF475569),
                    label: AppTranslations.tr(lang, "rain_chance", "Rain Chance"),
                    value: rainVal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Best Time to Spray (Next 48 Hours) Section
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF047857),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.access_time_filled_rounded, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  AppTranslations.tr(lang, "best_spray_timings", "Best Time to Spray"),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Spray Windows Schedule Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                  _buildSprayRow(
                    timeSlot: AppTranslations.tr(lang, "morning_slot", "Today Morning (06:30 – 10:00 AM)"),
                    hours: AppTranslations.tr(lang, "morning_reason", "Calm wind and optimal absorption"),
                    statusText: AppTranslations.tr(lang, "best_time", "Best time"),
                    isAllowed: true,
                    isBest: true,
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildSprayRow(
                    timeSlot: AppTranslations.tr(lang, "midday_slot", "Today Midday (11:30 AM – 03:30 PM)"),
                    hours: AppTranslations.tr(lang, "midday_reason", "Midday heat causes rapid droplet evaporation"),
                    statusText: AppTranslations.tr(lang, "no_spray", "Do not spray"),
                    isAllowed: false,
                    isBest: false,
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildSprayRow(
                    timeSlot: AppTranslations.tr(lang, "evening_slot", "Today Evening (04:00 – 07:00 PM)"),
                    hours: AppTranslations.tr(lang, "evening_reason", "Safe evening foliar window"),
                    statusText: AppTranslations.tr(lang, "moderate", "Can spray"),
                    isAllowed: true,
                    isBest: false,
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildSprayRow(
                    timeSlot: AppTranslations.tr(lang, "tomorrow_slot", "Tomorrow Morning (06:30 – 10:30 AM)"),
                    hours: AppTranslations.tr(lang, "tomorrow_reason", "Clear weather expected"),
                    statusText: AppTranslations.tr(lang, "best_time", "Best time"),
                    isAllowed: true,
                    isBest: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Common Crop Problems & Solutions Section
            Row(
              children: [
                const Icon(Icons.eco_rounded, color: Color(0xFF047857), size: 20),
                const SizedBox(width: 6),
                Text(
                  AppTranslations.tr(lang, "crop_diseases", "Common Crop Problems & Solutions"),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/crop_camera'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppTranslations.tr(lang, "view_all", "View All"),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF047857),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFF047857), size: 16),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Crop Problems Table / Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
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
                  _buildProblemItem(
                    cropIcon: Icons.grass_rounded,
                    name: AppTranslations.tr(lang, "wheat_disease", "Yellow / Stripe Rust"),
                    crop: AppTranslations.tr(lang, "wheat", "Wheat"),
                    symptoms: AppTranslations.tr(lang, "wheat_symptoms", "Yellow powder or stripes on leaves"),
                    dose: AppTranslations.tr(lang, "wheat_medicine", "Tilt 25% EC @ 200 ml per acre"),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildProblemItem(
                    cropIcon: Icons.spa_rounded,
                    name: "Whitefly & Leaf Curl",
                    crop: "Cotton",
                    symptoms: "White insects on leaf underside, leaf curling",
                    dose: "Pyriproxyfen 10% EC\n@ 400 ml per acre",
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildProblemItem(
                    cropIcon: Icons.forest_rounded,
                    name: "Late Blight",
                    crop: "Potato",
                    symptoms: "Dark spots on leaves in high humidity",
                    dose: "Mancozeb 75% WP\n@ 600 g per acre",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Disclaimer & Source Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF047857),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 12),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Weather conditions can change. Always check the latest update before spraying.",
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 1,
                    height: 24,
                    color: const Color(0xFFCBD5E1),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text("Source:", style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                      Text("Meteoblue", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSprayRow({
    required String timeSlot,
    required String hours,
    required String statusText,
    required bool isAllowed,
    required bool isBest,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              timeSlot,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              hours,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: !isAllowed
                  ? const Color(0xFFFEF2F2)
                  : isBest
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: !isAllowed
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFA7F3D0),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  !isAllowed
                      ? Icons.block_flipped
                      : Icons.check_circle_rounded,
                  size: 13,
                  color: !isAllowed ? const Color(0xFFDC2626) : const Color(0xFF047857),
                ),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: !isAllowed ? const Color(0xFFDC2626) : const Color(0xFF047857),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProblemItem({
    required IconData cropIcon,
    required String name,
    required String crop,
    required String symptoms,
    required String dose,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: Icon(cropIcon, color: const Color(0xFF047857), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  "($crop)",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              symptoms,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF475569),
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Recommended Dose:",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF047857),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dose,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDistrictPicker(
    BuildContext context,
    FarmProvider farmProv,
    List<dynamic> districts,
    String? currentDistrict,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Select District (Punjab)",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: districts.length,
                itemBuilder: (context, idx) {
                  final dist = districts[idx];
                  final isSel = dist.name == currentDistrict;
                  return ListTile(
                    leading: Icon(
                      Icons.location_on_rounded,
                      color: isSel ? const Color(0xFF047857) : const Color(0xFF94A3B8),
                    ),
                    title: Text(
                      dist.name,
                      style: TextStyle(
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                        color: isSel ? const Color(0xFF047857) : const Color(0xFF0F172A),
                      ),
                    ),
                    trailing: isSel ? const Icon(Icons.check_rounded, color: Color(0xFF047857)) : null,
                    onTap: () {
                      farmProv.selectPunjabDistrict(dist);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
