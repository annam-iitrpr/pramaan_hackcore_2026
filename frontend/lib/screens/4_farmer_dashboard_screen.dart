import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/farm_provider.dart';
import '../core/providers/evidence_provider.dart';
import '../widgets/custom_bottom_nav.dart';
import '../core/localization/app_translations.dart';

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  final int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveFarmerLogs();
    });
  }

  void _loadActiveFarmerLogs() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final evProv = Provider.of<EvidenceProvider>(context, listen: false);
    evProv.loadEvidenceForFarmer(phone: auth.userPhone, name: auth.userName);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final farmProv = Provider.of<FarmProvider>(context);
    final evProv = Provider.of<EvidenceProvider>(context);
    final farm = farmProv.selectedFarm;
    final lang = auth.selectedLanguage;

    final locationText = farm?.village.isNotEmpty == true
        ? "${farm!.village}, ${farm.state.isNotEmpty ? farm.state : 'Punjab'}"
        : (auth.userVillage.isNotEmpty
              ? "${auth.userVillage}, Punjab"
              : "Ludhiana, Punjab");

    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.menu_rounded,
            color: Color(0xFF0F172A),
            size: 24,
          ),
          onPressed: () => _showSideOptionsSheet(context, auth, farmProv),
        ),
        title: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.55,
          ),
          child: InkWell(
            onTap: () => _showFarmSelector(context, farmProv),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF047857),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      locationText,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF0F172A),
                  size: 24,
                ),
                onPressed: () => Navigator.pushNamed(context, '/notifications'),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF047857),
        onRefresh: () async {
          await farmProv.init();
          await evProv.loadEvidenceForFarmer(
            phone: auth.userPhone,
            name: auth.userName,
          );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Greeting & Weather Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            AppTranslations.tr(
                              lang,
                              "greeting_namaste",
                              "Namaste",
                            ),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text("🙏", style: TextStyle(fontSize: 20)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        auth.userName.isNotEmpty
                            ? "${AppTranslations.tr(lang, "welcome_back", "Welcome back")}, ${auth.userName} ji!"
                            : "${AppTranslations.tr(lang, "welcome_back", "Welcome back")}, Kisan ji!",
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wb_sunny_rounded,
                        color: Color(0xFFF59E0B),
                        size: 26,
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "28°C",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857),
                            ),
                          ),
                          Text(
                            AppTranslations.tr(
                              lang,
                              "partly_cloudy",
                              "Partly Cloudy",
                            ),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // // Active Crop Summary Card
              // _buildCropCard(context, farm, auth, lang),
              // const SizedBox(height: 14),

              // Field Weather Green Banner
              _buildFieldWeatherBanner(context, lang),
              const SizedBox(height: 18),

              // Quick Actions Section
              Text(
                AppTranslations.tr(lang, "quick_actions", "Quick Actions"),
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      title: AppTranslations.tr(lang, "voice_log", "Voice Log"),
                      icon: Icons.mic_rounded,
                      onTap: () => Navigator.pushNamed(context, '/voice_log'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionCard(
                      title: AppTranslations.tr(
                        lang,
                        "crop_camera_title",
                        "Crop Camera",
                      ),
                      icon: Icons.camera_alt_rounded,
                      onTap: () => Navigator.pushNamed(context, '/crop_camera'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      title: AppTranslations.tr(
                        lang,
                        "scan_bottle_title",
                        "Scan Bottle",
                      ),
                      icon: Icons.qr_code_scanner_rounded,
                      onTap: () =>
                          Navigator.pushNamed(context, '/scan_product'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildQuickActionCard(
                      title: AppTranslations.tr(
                        lang,
                        "new_spray_title",
                        "Spray Log",
                      ),
                      icon: Icons.science_rounded,
                      onTap: () =>
                          Navigator.pushNamed(context, '/new_application'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Recent Activities Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppTranslations.tr(
                      lang,
                      "recent_activities",
                      "Recent Activities",
                    ),
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  InkWell(
                    onTap: () =>
                        Navigator.pushNamed(context, '/evidence_review'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        AppTranslations.tr(lang, "view_all", "View All"),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Recent Activities List
              _buildRecentActivitiesList(evProv, lang),
              const SizedBox(height: 16),

              // Kisan Tip of the Day Card
              _buildKisanTipCard(lang),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(currentIndex: _navIndex),
    );
  }

  String _localizeCrop(String name, String lang) {
    final lower = name.toLowerCase();
    if (lower.contains('cotton') ||
        lower.contains('कापूस') ||
        lower.contains('कपास')) {
      if (lang == 'hi') return 'कपास (Bt-II)';
      if (lang == 'mr') return 'कापूस (Bt-II)';
      if (lang == 'pa') return 'ਨਰਮਾ/ਕਪਾਹ (Bt-II)';
      return 'Cotton (Bt-II)';
    } else if (lower.contains('wheat') ||
        lower.contains('गहू') ||
        lower.contains('गेहूं')) {
      if (lang == 'hi') return 'गेहूं';
      if (lang == 'mr') return 'गहू';
      if (lang == 'pa') return 'ਕਣਕ';
      return 'Wheat';
    } else if (lower.contains('paddy') ||
        lower.contains('rice') ||
        lower.contains('धान')) {
      if (lang == 'hi') return 'धान';
      if (lang == 'mr') return 'भात/धान';
      if (lang == 'pa') return 'ਝੋਨਾ';
      return 'Paddy';
    }
    return name;
  }

  String _localizeStage(String stage, String lang) {
    final lower = stage.toLowerCase();
    if (lower.contains('tillering') ||
        lower.contains('canopy') ||
        lower.contains('कल्ले') ||
        lower.contains('फुटवे')) {
      if (lang == 'hi') return 'कल्ले फूटने और बढ़वार की अवस्था';
      if (lang == 'mr') return 'फुटवे आणि जोमदार वाढीची अवस्था';
      if (lang == 'pa') return 'ਫੁਟਾਰਾ ਅਤੇ ਵਾਧਾ ਅਵਸਥਾ';
      return 'Active Tillering & Canopy Development';
    } else if (lower.contains('boll') ||
        lower.contains('flower') ||
        lower.contains('बोंड') ||
        lower.contains('टिंडे')) {
      if (lang == 'hi') return 'फूल और टिंडे बनने की अवस्था';
      if (lang == 'mr') return 'फुलोरा आणि बोंड धरण्याची अवस्था';
      if (lang == 'pa') return 'ਫੁੱਲ ਤੇ ਟੀਂਡੇ ਬਣਨ ਦੀ ਅਵਸਥਾ';
      return 'Boll Formation / Flowering';
    } else if (lower.contains('grain') ||
        lower.contains('milking') ||
        lower.contains('filling') ||
        lower.contains('दाने')) {
      if (lang == 'hi') return 'दाना भराव एवं दुग्ध अवस्था';
      if (lang == 'mr') return 'दाणे भरणे आणि दुधाळ अवस्था';
      if (lang == 'pa') return 'ਦਾਣਾ ਭਰਨ ਦੀ ਅਵਸਥਾ';
      return 'Grain Filling / Milking Stage';
    } else if (lower.contains('maturity') ||
        lower.contains('harvest') ||
        lower.contains('काढणी') ||
        lower.contains('कटाई')) {
      if (lang == 'hi') return 'परिपक्वता एवं कटाई अवस्था';
      if (lang == 'mr') return 'परिपक्वता आणि काढणी अवस्था';
      if (lang == 'pa') return 'ਪੱਕਣ ਅਤੇ ਵਾਢੀ ਦੀ ਅਵਸਥਾ';
      return 'Maturity & Harvesting Stage';
    } else if (lower.contains('seedling') ||
        lower.contains('germination') ||
        lower.contains('अंकुरण')) {
      if (lang == 'hi') return 'अंकुरण एवं प्रारंभिक अवस्था';
      if (lang == 'mr') return 'उगवण आणि प्राथमिक अवस्था';
      if (lang == 'pa') return 'ਪੁੰਗਰਨ ਅਤੇ ਮੁੱਢਲੀ ਅਵਸਥਾ';
      return 'Germination & Seedling Stage';
    } else if (lower.contains('vegetative')) {
      if (lang == 'hi') return 'वानस्पतिक विकास अवस्था';
      if (lang == 'mr') return 'शाकीय वाढीची अवस्था';
      if (lang == 'pa') return 'ਵਿਕਾਸ ਅਵਸਥਾ';
      return 'Vegetative Stage';
    }
    return stage;
  }

  Widget _buildCropCard(
    BuildContext context,
    dynamic farm,
    AuthProvider auth,
    String lang,
  ) {
    final rawCropName = farm?.activeCrop ?? auth.activeCrop;
    final rawStage = farm?.cropStage ?? "Boll Formation / Flowering";
    final cropName = _localizeCrop(
      rawCropName.toString().isNotEmpty ? rawCropName.toString() : "Cotton",
      lang,
    );
    final stage = _localizeStage(rawStage.toString(), lang);
    final acres = farm?.totalAcres ?? 12.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Crop Illustration Icon Container
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.spa_rounded,
                color: Color(0xFF047857),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      cropName,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        "96% ${AppTranslations.tr(lang, "compliance_label", "Compliance")}",
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "${AppTranslations.tr(lang, "stage_label", "Stage:")} $stage",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  "${AppTranslations.tr(lang, "area_label", "Area:")} $acres ${AppTranslations.tr(lang, "acres_unit", "Acres")}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF94A3B8),
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldWeatherBanner(BuildContext context, String lang) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/agronomy_suite'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D6E4F), Color(0xFF15803D), Color(0xFF10B981)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF047857).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.eco_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppTranslations.tr(
                                lang,
                                "field_weather",
                                "Field Weather",
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const Text(
                              "28.5°C",
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.air_rounded,
                                      color: Colors.white70,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      "${AppTranslations.tr(lang, "wind", "Wind")}: 5.4 km/h",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 1),
                                // Text(
                                //   AppTranslations.tr(
                                //     lang,
                                //     "calm_ideal_spray",
                                //     "Calm winds and\nideal for spraying",
                                //   ),
                                //   style: const TextStyle(
                                //     color: Color(0xFFD1FAE5),
                                //     fontSize: 10.5,
                                //     height: 1.2,
                                //   ),
                                // ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Sun & field landscape artwork graphic
                  Container(
                    width: 76,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 8,
                          child: Icon(
                            Icons.wb_sunny_rounded,
                            color: Color(0xFFFDE047),
                            size: 26,
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          child: Icon(
                            Icons.grass_rounded,
                            color: Color(0xFF86EFAC),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom banner pill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF047857),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppTranslations.tr(
                      lang,
                      "safe_to_spray",
                      "Great conditions for spraying!",
                    ),
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // Split title into two lines
    String firstLine = title;
    String secondLine = '';

    if (title == "Voice Log") {
      firstLine = "Voice";
      secondLine = "Log";
    } else if (title == "Crop Camera") {
      firstLine = "Crop";
      secondLine = "Camera";
    } else if (title == "Scan Bottle") {
      firstLine = "Scan";
      secondLine = "Bottle";
    } else if (title == "New Spray Log" || title == "Spray Log") {
      firstLine = "Spray";
      secondLine = "Log";
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 82,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAF9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8EFEB), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF047857).withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F8F1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF047857), size: 21),
              ),

              const SizedBox(width: 10),

              // Two-line title
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      secondLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatActivityDateTime(String timestamp) {
    if (timestamp.isEmpty) {
      return "Today";
    }

    final parsedDate = DateTime.tryParse(timestamp);

    if (parsedDate == null) {
      return timestamp;
    }

    final localDate = parsedDate.toLocal();

    final dateText = MaterialLocalizations.of(
      context,
    ).formatMediumDate(localDate);

    final timeText = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(localDate),
      alwaysUse24HourFormat: false,
    );

    return "$dateText • $timeText";
  }

  String _getActivityTitle(String evidenceType) {
    switch (evidenceType) {
      case 'VOICE_RECORDING':
      case 'OBSERVATION':
        return "Voice Log";
      case 'CROP_IMAGE':
        return "Crop Photo";
      case 'PRODUCT_SCAN':
        return "Product Scan";
      case 'APPLICATION_LOG':
        return "Spray Log";
      default:
        return "Activity";
    }
  }

  Widget _buildRecentActivitiesList(EvidenceProvider evProv, String lang) {
    if (evProv.evidenceList.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            _buildActivityItem(
              title: AppTranslations.tr(
                lang,
                "voice_log_added_title",
                "Voice Log Added",
              ),
              subtitle: AppTranslations.tr(
                lang,
                "voice_log_added_sub",
                "Insecticide spray on cotton field",
              ),
              time: AppTranslations.tr(
                lang,
                "time_today_morning",
                "Today, 8:30 AM",
              ),
              icon: Icons.mic_rounded,
              onTap: () => Navigator.pushNamed(context, '/evidence_review'),
            ),
            const Divider(
              height: 1,
              indent: 56,
              endIndent: 16,
              color: Color(0xFFF1F5F9),
            ),
            _buildActivityItem(
              title: AppTranslations.tr(
                lang,
                "crop_photo_captured_title",
                "Crop Photo Captured",
              ),
              subtitle: AppTranslations.tr(
                lang,
                "crop_photo_captured_sub",
                "AI analysis completed",
              ),
              time: AppTranslations.tr(
                lang,
                "time_today_earlier",
                "Today, 7:45 AM",
              ),
              icon: Icons.camera_alt_rounded,
              onTap: () => Navigator.pushNamed(context, '/evidence_review'),
            ),
          ],
        ),
      );
    }

    final displayItems = evProv.evidenceList.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: List.generate(displayItems.length, (idx) {
          final item = displayItems[idx];
          IconData itemIcon = Icons.note_alt_rounded;
          if (item.evidenceType == 'VOICE_RECORDING' ||
              item.evidenceType == 'OBSERVATION') {
            itemIcon = Icons.mic_rounded;
          } else if (item.evidenceType == 'CROP_IMAGE') {
            itemIcon = Icons.camera_alt_rounded;
          } else if (item.evidenceType == 'PRODUCT_SCAN') {
            itemIcon = Icons.qr_code_scanner_rounded;
          } else if (item.evidenceType == 'APPLICATION_LOG') {
            itemIcon = Icons.science_rounded;
          }

          return Column(
            children: [
              _buildActivityItem(
                title: _getActivityTitle(item.evidenceType),
                subtitle: item.description.isNotEmpty
                    ? item.description
                    : "Activity recorded",
                time: _formatActivityDateTime(item.timestamp),
                icon: itemIcon,
                onTap: () => Navigator.pushNamed(
                  context,
                  '/evidence_detail',
                  arguments: item,
                ),
              ),
              if (idx < displayItems.length - 1)
                const Divider(
                  height: 1,
                  indent: 56,
                  endIndent: 16,
                  color: Color(0xFFF1F5F9),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildActivityItem({
    required String title,
    required String subtitle,
    required String time,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Activity icon
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFECFDF5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF047857), size: 19),
            ),

            const SizedBox(width: 11),

            // Activity information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Activity title
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 3),

                  // Activity description
                  Text(
                    subtitle.isNotEmpty ? subtitle : "Activity recorded",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                      height: 1.25,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Human-readable date and time
                  Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Completed status
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF047857),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKisanTipCard(String lang) {
    String tipText;
    switch (lang) {
      case 'pa':
        tipText = "ਛਿੜਕਾਅ ਸਵੇਰੇ ਜਾਂ ਸ਼ਾਮ ਨੂੰ ਕਰੋ, ਦਵਾਈ ਦਾ ਪੂਰਾ ਅਸਰ ਹੋਵੇਗਾ।";
        break;
      case 'mr':
        tipText = "फवारणी सकाळी किंवा संध्याकाळी करा, चांगल्या परिणामासाठी.";
        break;
      case 'en':
        tipText =
            "Spray during early morning or evening for maximum absorption.";
        break;
      case 'hi':
      default:
        tipText = "छिड़काव सुबह या शाम के समय करें, दवा का पूरा असर मिलेगा।";
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          // Farmer cartoon avatar illustration
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: const Center(
              child: Text("👨‍🌾", style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.tr(
                    lang,
                    "kisan_tip_title",
                    "Kisan Tip of the Day",
                  ),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tipText,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x1AF59E0B),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: Color(0xFFF59E0B),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  void _showSideOptionsSheet(
    BuildContext context,
    AuthProvider auth,
    FarmProvider farmProv,
  ) {
    final lang = auth.selectedLanguage;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sync_rounded, color: Color(0xFF047857)),
              title: Text(
                AppTranslations.tr(
                  lang,
                  "sync_center_menu",
                  "Sync Center & Google Sheets",
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/sync_center');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.groups_rounded,
                color: Color(0xFF047857),
              ),
              title: Text(
                AppTranslations.tr(
                  lang,
                  "community_logs_menu",
                  "Community Logs",
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/community_logs');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.language_rounded,
                color: Color(0xFF047857),
              ),
              title: Text(
                "${AppTranslations.tr(lang, "language_menu", "Language")}: ${AppTranslations.getLanguageName(auth.selectedLanguage)}",
              ),
              onTap: () {
                Navigator.pop(ctx);
                AppTranslations.showLanguageSelectorModal(
                  context,
                  auth.selectedLanguage,
                  (newLang) => auth.setLanguage(newLang),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.switch_account_rounded,
                color: Color(0xFF047857),
              ),
              title: Text(
                AppTranslations.tr(
                  lang,
                  "switch_role_menu",
                  "Switch Profile / Role",
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/profile_selection');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_rounded,
                color: Color(0xFF047857),
              ),
              title: Text(
                AppTranslations.tr(lang, "settings_menu", "Settings"),
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/settings');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFarmSelector(BuildContext context, FarmProvider farmProv) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final lang = auth.selectedLanguage;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppTranslations.tr(
                      lang,
                      "switch_plot_title",
                      "Switch Agricultural Plot / Farm",
                    ),
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
              const SizedBox(height: 10),
              ...farmProv.farms.map((f) {
                final isCurrent = farmProv.selectedFarm?.id == f.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFFECFDF5) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFF047857)
                          : const Color(0xFFE2E8F0),
                      width: isCurrent ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF047857),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      f.name,
                      style: TextStyle(
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      "${f.village}, ${f.state} • ${f.activeCrop}",
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: isCurrent
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF047857),
                          )
                        : null,
                    onTap: () {
                      farmProv.selectFarm(f);
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
