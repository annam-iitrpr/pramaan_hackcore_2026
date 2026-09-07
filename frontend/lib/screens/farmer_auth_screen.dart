import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/farm_provider.dart';
import '../core/providers/evidence_provider.dart';
import '../core/services/google_sheets_service.dart';
import '../core/localization/app_translations.dart';

class FarmerAuthScreen extends StatefulWidget {
  const FarmerAuthScreen({super.key});

  @override
  State<FarmerAuthScreen> createState() => _FarmerAuthScreenState();
}

class _FarmerAuthScreenState extends State<FarmerAuthScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _villageController = TextEditingController(text: "Nashik");
  final _stateController = TextEditingController(text: "Maharashtra");
  final _cropController = TextEditingController(text: "Cotton");
  final _acresController = TextEditingController(text: "10.0");

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    _stateController.dispose();
    _cropController.dispose();
    _acresController.dispose();
    super.dispose();
  }

  void _loginFarmerAccount() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final lang = auth.selectedLanguage;

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.tr(
              lang,
              "enter_name_phone_error",
              "Please enter your name & mobile number",
            ),
          ),
          backgroundColor: AppColors.flaggedRed,
        ),
      );
      return;
    }

    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.tr(
              lang,
              "enter_valid_phone_error",
              "Please enter valid 10-digit mobile number",
            ),
          ),
          backgroundColor: AppColors.flaggedRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final finalVillage = _villageController.text.trim().isNotEmpty
        ? _villageController.text.trim()
        : "Nashik";
    final finalState = _stateController.text.trim().isNotEmpty
        ? _stateController.text.trim()
        : "Maharashtra";
    final finalCrop = _cropController.text.trim().isNotEmpty
        ? _cropController.text.trim()
        : "Cotton";
    final finalAcres = double.tryParse(_acresController.text.trim()) ?? 10.0;

    final evProv = Provider.of<EvidenceProvider>(context, listen: false);
    final farmProv = Provider.of<FarmProvider>(context, listen: false);

    // 1. Live Google Sheets Webhook Sync (Farmers Tab)
    try {
      final res = await GoogleSheetsService().loginOrRegisterFarmer(
        name: name,
        phone: phone,
        village: finalVillage,
        state: finalState,
        crop: finalCrop,
        acres: finalAcres,
      );

      debugPrint("[Farmer Auth] Google Sheets result: $res");

      // Check if server returned NAME_MISMATCH error
      if (res['status'] == 'error' &&
          (res['error_type'] == 'NAME_MISMATCH' ||
              res['registered_name'] != null)) {
        if (mounted) {
          setState(() => _isLoading = false);
          final registeredName = res['registered_name']?.toString() ?? "";
          _showNameMismatchDialog(registeredName, phone, lang);
        }
        return;
      }

      if (res['farmer'] != null) {
        final f = res['farmer'];
        final actualName = f['name']?.toString() ?? name;
        final actualPhone = f['phone']?.toString() ?? phone;
        final actualVillage = f['village']?.toString() ?? finalVillage;
        final actualState = f['state']?.toString() ?? finalState;
        final actualCrop = f['crop']?.toString() ?? finalCrop;
        final actualAcres = (f['acres'] as num?)?.toDouble() ?? finalAcres;

        auth.loginFarmer(
          name: actualName,
          phone: actualPhone,
          village: actualVillage,
          state: actualState,
          crop: actualCrop,
          acres: actualAcres,
        );

        evProv.setActiveFarmer(phone: actualPhone, name: actualName);
      } else {
        auth.loginFarmer(
          name: name,
          phone: phone,
          village: finalVillage,
          state: finalState,
          crop: finalCrop,
          acres: finalAcres,
        );
        evProv.setActiveFarmer(phone: phone, name: name);
      }
    } catch (e) {
      debugPrint("[Farmer Auth] Sync warning: $e");
      auth.loginFarmer(
        name: name,
        phone: phone,
        village: finalVillage,
        state: finalState,
        crop: finalCrop,
        acres: finalAcres,
      );
      evProv.setActiveFarmer(phone: phone, name: name);
    }

    // Match farm if available
    try {
      final matchedFarm = farmProv.farms.firstWhere(
        (f) => f.state.toLowerCase() == finalState.toLowerCase(),
        orElse: () => farmProv.farms.first,
      );
      farmProv.selectFarm(matchedFarm);
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
      final welcomeTemplate = AppTranslations.tr(
        lang,
        "login_welcome_msg",
        "Welcome {name}! Logged in successfully.",
      );
      final welcomeText = welcomeTemplate.replaceAll("{name}", auth.userName);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(welcomeText),
          backgroundColor: const Color(0xFF166534),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pushReplacementNamed(context, '/farmer_dashboard');
    }
  }

  void _showNameMismatchDialog(
    String registeredName,
    String phone,
    String lang,
  ) {
    final title = AppTranslations.tr(
      lang,
      "name_mismatch_title",
      "Name Mismatch",
    );
    final desc = AppTranslations.tr(
      lang,
      "name_mismatch_desc",
      "Mobile number +91 {phone} is already registered under:",
    ).replaceAll("{phone}", phone);
    final secInfo = AppTranslations.tr(
      lang,
      "name_mismatch_sec",
      "For data security, registered account names cannot be changed.",
    );
    final editBtn = AppTranslations.tr(lang, "edit_name", "Edit Name");
    final useNameBtn =
        "${AppTranslations.tr(lang, "use_this_name", "Use this name")} ('$registeredName')";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFD97706),
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              desc,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF166534),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      registeredName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              secInfo,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              editBtn,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF166534),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: Text(useNameBtn),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _nameController.text = registeredName;
              });
              _loginFarmerAccount();
            },
          ),
        ],
      ),
    );
  }

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
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Bottom Scenic Agricultural Landscape (Fixed to bottom)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FarmLandscapeFooter(lang: lang),
          ),

          // 2. Foreground Interactive & Scrollable Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top Navigation Back Button & Language Switcher Pill
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 16, top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF1E293B),
                          size: 24,
                        ),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(
                              context,
                              '/profile_selection',
                            );
                          }
                        },
                      ),
                      // Language Selector Pill
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () =>
                              AppTranslations.showLanguageSelectorModal(
                                context,
                                auth.selectedLanguage,
                                (newLang) => auth.setLanguage(newLang),
                              ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF86EFAC),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF166534,
                                  ).withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.language_rounded,
                                  size: 17,
                                  color: Color(0xFF166534),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getLanguageDisplayName(
                                    auth.selectedLanguage,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF166534),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: Color(0xFF166534),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content with dynamic keyboard bottom clearance
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: MediaQuery.of(context).viewInsets.bottom > 0
                          ? MediaQuery.of(context).viewInsets.bottom + 20
                          : 160,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        // 1. Pramaan Brand Logo Image
                        const _PramaanLogoWidget(),

                        const SizedBox(height: 22),

                        // 2. Title Section
                        Text(
                          lang == 'en'
                              ? "Farmer Login"
                              : AppTranslations.tr(
                                  lang,
                                  "farmer_login_title",
                                  _getLocalizedLoginTitle(lang),
                                ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: lang == 'en' ? 27 : 25,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF133E2B),
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const SizedBox(height: 28),
                        const SizedBox(height: 32),

                        // 3. Farmer Name Input Field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                          ),
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 14, right: 10),
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF1B6B43),
                                  size: 24,
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 48,
                              ),
                              hintText: _getNameHint(lang),
                              hintStyle: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 4. Mobile Number Input Field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              width: 1.2,
                            ),
                          ),
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Padding(
                                padding: EdgeInsets.only(left: 14, right: 10),
                                child: Icon(
                                  Icons.smartphone_rounded,
                                  color: Color(0xFF1B6B43),
                                  size: 24,
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 48,
                              ),
                              hintText: _getPhoneHint(lang),
                              hintStyle: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // 5. Action Button: Enter My Farm
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _loginFarmerAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1B6B43),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _getButtonLabel(lang),
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedLoginSubtitle(String lang) {
    switch (lang) {
      case 'mr':
        return "पुढे जाण्यासाठी आपले नाव आणि मोबाईल नंबर टाका";
      case 'hi':
        return "जारी रखने के लिए अपना नाम और मोबाइल नंबर दर्ज करें";
      case 'pa':
        return "ਜਾਰੀ ਰੱਖਣ ਲਈ ਆਪਣਾ ਨਾਮ ਅਤੇ ਮੋਬਾਈਲ ਨੰਬਰ ਦਰਜ ਕਰੋ";
      default:
        return "Enter your name and mobile number to continue";
    }
  }

  String _getNameHint(String lang) {
    switch (lang) {
      case 'mr':
        return "शेतकऱ्याचे पूर्ण नाव";
      case 'hi':
        return "किसान का पूरा नाम";
      case 'pa':
        return "ਕਿਸਾਨ ਦਾ ਪੂਰਾ ਨਾਮ";
      default:
        return "Farmer Full Name";
    }
  }

  String _getLocalizedLoginTitle(String lang) {
    switch (lang) {
      case 'mr':
        return "शेतकरी लॉगिन";
      case 'hi':
        return "किसान लॉगिन";
      case 'pa':
        return "ਕਿਸਾਨ ਲਾਗਇਨ";
      default:
        return "Farmer Login";
    }
  }

  String _getPhoneHint(String lang) {
    switch (lang) {
      case 'mr':
        return "मोबाईल नंबर";
      case 'hi':
        return "मोबाइल नंबर (10 अंक)";
      case 'pa':
        return "ਮੋਬਾਈਲ ਨੰਬਰ (10 ਅੰਕ)";
      default:
        return "Mobile Number (10 digits)";
    }
  }

  String _getButtonLabel(String lang) {
    switch (lang) {
      case 'mr':
        return "लॉगिन करा";

      case 'hi':
        return "लॉगिन करें";

      case 'pa':
        return "ਲੌਗਇਨ ਕਰੋ";

      default:
        return "Login";
    }
  }
}

/// Stylized Pramaan Brand Header Logo Widget
class _PramaanLogoWidget extends StatelessWidget {
  const _PramaanLogoWidget();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Center(
        child: Image.asset(
          'assets/images/pramaan_logo.png',
          height: 75,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

/// Bottom Agricultural Rolling Hills Landscape with Cottage and Slogan
class _FarmLandscapeFooter extends StatelessWidget {
  final String lang;
  const _FarmLandscapeFooter({required this.lang});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 145,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Rolling Hills Background
          CustomPaint(
            size: const Size(double.infinity, 145),
            painter: _FarmLandscapePainter(),
          ),

          // Farmhouse Silhouette & Trees on Right Hill
          Positioned(
            right: 48,
            bottom: 46,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Small Cottage
                Container(
                  width: 30,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF658A6A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Stack(
                    children: [
                      // Roof
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 6,
                          color: const Color(0xFF436348),
                        ),
                      ),
                      // Window
                      Positioned(
                        top: 8,
                        left: 6,
                        child: Container(
                          width: 5,
                          height: 5,
                          color: const Color(0xFFE8F2E8),
                        ),
                      ),
                      // Door
                      Positioned(
                        bottom: 0,
                        right: 6,
                        child: Container(
                          width: 5,
                          height: 9,
                          color: const Color(0xFF436348),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Trees
                const Icon(
                  Icons.park_rounded,
                  size: 26,
                  color: Color(0xFF7FA884),
                ),
                const Icon(
                  Icons.park_rounded,
                  size: 32,
                  color: Color(0xFF587D5D),
                ),
              ],
            ),
          ),

          // Lush Foliage Leaves on Bottom Left
          Positioned(
            left: 8,
            bottom: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Transform.rotate(
                  angle: -0.45,
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 46,
                    color: Color(0xFF436348),
                  ),
                ),
                Transform.rotate(
                  angle: -0.15,
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 34,
                    color: Color(0xFF5E8463),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Slogan (Purely Localized)
          Positioned(
            bottom: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 0.8,
                  color: const Color(0xFF436348),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    AppTranslations.tr(
                      lang,
                      "sustainable_slogan",
                      "SUSTAINABLE FARMING FOR A BRIGHTER TOMORROW",
                    ),
                    style: const TextStyle(
                      fontSize: 9.0,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Color(0xFF2D4B32),
                    ),
                  ),
                ),
                Container(
                  width: 24,
                  height: 0.8,
                  color: const Color(0xFF436348),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FarmLandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Back Hills (lightest sage)
    final backHillPaint = Paint()
      ..color = const Color(0xFFE5EDE4)
      ..style = PaintingStyle.fill;

    final backPath = Path();
    backPath.moveTo(0, size.height * 0.35);
    backPath.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.1,
      size.width * 0.65,
      size.height * 0.3,
    );
    backPath.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.4,
      size.width,
      size.height * 0.25,
    );
    backPath.lineTo(size.width, size.height);
    backPath.lineTo(0, size.height);
    backPath.close();
    canvas.drawPath(backPath, backHillPaint);

    // Middle Hill (gentle green)
    final midHillPaint = Paint()
      ..color = const Color(0xFFD3E3D1)
      ..style = PaintingStyle.fill;

    final midPath = Path();
    midPath.moveTo(0, size.height * 0.55);
    midPath.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.35,
      size.width * 0.55,
      size.height * 0.5,
    );
    midPath.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.6,
      size.width,
      size.height * 0.4,
    );
    midPath.lineTo(size.width, size.height);
    midPath.lineTo(0, size.height);
    midPath.close();
    canvas.drawPath(midPath, midHillPaint);

    // Front Hill (soft rich green)
    final frontHillPaint = Paint()
      ..color = const Color(0xFFBCCFB9)
      ..style = PaintingStyle.fill;

    final frontPath = Path();
    frontPath.moveTo(0, size.height * 0.72);
    frontPath.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.55,
      size.width * 0.7,
      size.height * 0.68,
    );
    frontPath.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.75,
      size.width,
      size.height * 0.62,
    );
    frontPath.lineTo(size.width, size.height);
    frontPath.lineTo(0, size.height);
    frontPath.close();
    canvas.drawPath(frontPath, frontHillPaint);

    // Subtle crop contour lines
    final contourPaint = Paint()
      ..color = const Color(0xFFA8BD9F).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final contourPath = Path();
    contourPath.moveTo(0, size.height * 0.82);
    contourPath.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.7,
      size.width * 0.8,
      size.height * 0.8,
    );
    canvas.drawPath(contourPath, contourPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
