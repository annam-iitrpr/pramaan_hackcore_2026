import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/farm_provider.dart';
import '../core/providers/evidence_provider.dart';
import '../core/services/api_service.dart';
import '../core/services/google_sheets_service.dart';
import '../core/localization/app_translations.dart';

enum AuthStep { phone, otp }

class FarmerAuthScreen extends StatefulWidget {
  const FarmerAuthScreen({super.key});

  @override
  State<FarmerAuthScreen> createState() => _FarmerAuthScreenState();
}

class _FarmerAuthScreenState extends State<FarmerAuthScreen> {
  AuthStep _currentStep = AuthStep.phone;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _villageController = TextEditingController(text: "Nashik");
  final _stateController = TextEditingController(text: "Maharashtra");
  final _cropController = TextEditingController(text: "Cotton");
  final _acresController = TextEditingController(text: "10.0");

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _resendCountdown = 0;
  Timer? _resendTimer;
  String? _errorMessage;
  String _normalizedPhone = "";

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    _stateController.dispose();
    _cropController.dispose();
    _acresController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final fn in _otpFocusNodes) {
      fn.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 30;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 1) {
          _resendCountdown--;
        } else {
          _resendCountdown = 0;
          timer.cancel();
        }
      });
    });
  }

  bool get _isOtpComplete {
    return _otpControllers.every((c) => c.text.trim().isNotEmpty);
  }

  String get _currentOtpCode {
    return _otpControllers.map((c) => c.text.trim()).join();
  }

  String _getMaskedPhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length >= 10) {
      final last4 = clean.substring(clean.length - 4);
      return "+91 XXXXX $last4";
    }
    return phone;
  }

  void _handleSendOtp() async {
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService().sendOtp(phone);
      if (mounted) {
        for (var c in _otpControllers) {
          c.clear();
        }
        _normalizedPhone =
            res['phone']?.toString() ??
            (phone.startsWith("+") ? phone : "+91$phone");
        setState(() {
          _isLoading = false;
          _currentStep = AuthStep.otp;
        });
        _startResendTimer();
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && _otpFocusNodes.isNotEmpty) {
            _otpFocusNodes[0].requestFocus();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppTranslations.tr(
                lang,
                "otp_sent_success",
                "OTP sent successfully to your mobile number",
              ),
            ),
            backgroundColor: const Color(0xFF166534),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().replaceAll("Exception:", "").trim();
        setState(() {
          _isLoading = false;
          _errorMessage = errStr;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errStr.isNotEmpty
                  ? errStr
                  : AppTranslations.tr(
                      lang,
                      "otp_send_failed",
                      "Failed to send OTP. Please check your number and try again.",
                    ),
            ),
            backgroundColor: AppColors.flaggedRed,
          ),
        );
      }
    }
  }

  void _handleResendOtp() async {
    if (_resendCountdown > 0 || _isLoading) return;
    final phone = _phoneController.text.trim();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final lang = auth.selectedLanguage;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService().sendOtp(phone);
      if (mounted) {
        for (var c in _otpControllers) {
          c.clear();
        }
        setState(() {
          _isLoading = false;
        });
        _startResendTimer();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _otpFocusNodes.isNotEmpty) {
            _otpFocusNodes[0].requestFocus();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppTranslations.tr(
                lang,
                "otp_resent_success",
                "A new OTP has been sent to your phone",
              ),
            ),
            backgroundColor: const Color(0xFF166534),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().replaceAll("Exception:", "").trim();
        setState(() {
          _isLoading = false;
          _errorMessage = errStr;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errStr.isNotEmpty
                  ? errStr
                  : AppTranslations.tr(
                      lang,
                      "otp_send_failed",
                      "Failed to resend OTP. Please try again.",
                    ),
            ),
            backgroundColor: AppColors.flaggedRed,
          ),
        );
      }
    }
  }

  void _handleVerifyOtp() async {
    final otp = _currentOtpCode;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final lang = auth.selectedLanguage;

    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.tr(
              lang,
              "enter_complete_otp",
              "Please enter the complete 6-digit OTP",
            ),
          ),
          backgroundColor: AppColors.flaggedRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final finalVillage = _villageController.text.trim().isNotEmpty
        ? _villageController.text.trim()
        : "Nashik";
    final finalState = _stateController.text.trim().isNotEmpty
        ? _stateController.text.trim()
        : "Maharashtra";
    final finalCrop = _cropController.text.trim().isNotEmpty
        ? _cropController.text.trim()
        : "Cotton";
    final finalAcres =
        double.tryParse(_acresController.text.trim()) ?? 10.0;

    // 1. Verify OTP with Backend & Twilio Verify
    try {
      final verifyRes = await ApiService().verifyOtp(
        phone: phone,
        otp: otp,
        name: name,
        village: finalVillage,
        state: finalState,
        crop: finalCrop,
        acres: finalAcres,
      );

      debugPrint("[Farmer Auth] Verify OTP API result: $verifyRes");
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().replaceAll("Exception:", "").trim();
        setState(() {
          _isLoading = false;
          _errorMessage = errStr;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errStr.isNotEmpty
                  ? errStr
                  : AppTranslations.tr(
                      lang,
                      "invalid_otp_error",
                      "Invalid or expired OTP. Please try again.",
                    ),
            ),
            backgroundColor: AppColors.flaggedRed,
          ),
        );
      }
      return;
    }

    // 2. Live MongoDB Atlas Authentication & Profile Retrieval
    String actualName = name;
    String actualPhone = phone;
    String actualVillage = finalVillage;
    String actualState = finalState;
    String actualCrop = finalCrop;
    double actualAcres = finalAcres;

    try {
      final mongoRes = await ApiService().loginFarmerMongo(
        name: name,
        phone: phone,
        district: finalVillage,
        village: finalVillage,
        state: finalState,
        crop: finalCrop,
        acres: finalAcres,
      );

      debugPrint("[Farmer Auth] MongoDB Atlas login result: $mongoRes");

      if (mongoRes['farmer'] != null) {
        final f = mongoRes['farmer'];
        actualName = f['name']?.toString() ?? name;
        actualPhone = f['phone']?.toString() ?? phone;
        actualVillage =
            (f['district'] ?? f['village'])?.toString() ?? finalVillage;
        actualState = f['state']?.toString() ?? finalState;
        actualCrop = (f['primary_crop'] ?? f['crop'])?.toString() ?? finalCrop;
        actualAcres =
            (f['farm_size_acres'] ?? f['acres'] as num?)?.toDouble() ??
            finalAcres;
      }
    } catch (mongoErr) {
      debugPrint("[Farmer Auth] MongoDB direct call note: $mongoErr");
    }

    // 3. Google Sheets Hybrid Sync (Farmers Tab)
    try {
      final res = await GoogleSheetsService().loginOrRegisterFarmer(
        name: actualName,
        phone: actualPhone,
        village: actualVillage,
        state: actualState,
        crop: actualCrop,
        acres: actualAcres,
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
    } catch (e) {
      debugPrint("[Farmer Auth] Sheet sync note: $e");
    }

    if (!mounted) return;

    // 4. Set Session in Providers
    auth.loginFarmer(
      name: actualName,
      phone: actualPhone,
      village: actualVillage,
      state: actualState,
      crop: actualCrop,
      acres: actualAcres,
    );

    final evProv = Provider.of<EvidenceProvider>(context, listen: false);
    evProv.setActiveFarmer(phone: actualPhone, name: actualName);

    final farmProv = Provider.of<FarmProvider>(context, listen: false);
    try {
      final matchedFarm = farmProv.farms.firstWhere(
        (f) => f.state.toLowerCase() == finalState.toLowerCase(),
        orElse: () => farmProv.farms.first,
      );
      farmProv.selectFarm(matchedFarm);
    } catch (_) {}

    setState(() => _isLoading = false);
    final welcomeTemplate = AppTranslations.tr(
      lang,
      "login_welcome_msg",
      "Welcome {name}! Logged in successfully.",
    );
    final welcomeText =
        welcomeTemplate.replaceAll("{name}", auth.userName);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(welcomeText),
        backgroundColor: const Color(0xFF166534),
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pushReplacementNamed(context, '/farmer_dashboard');
  }

  void _onOtpDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _otpControllers[i].text = digits[i];
      }
      final targetIndex = (digits.length >= 6) ? 5 : digits.length;
      if (targetIndex < 6) {
        _otpFocusNodes[targetIndex].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
      }
      setState(() {});
      if (digits.length == 6) {
        _handleVerifyOtp();
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
        if (_isOtpComplete) {
          _handleVerifyOtp();
        }
      }
    }
    setState(() {});
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
              _handleVerifyOtp();
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
                          if (_currentStep == AuthStep.otp) {
                            setState(() {
                              _currentStep = AuthStep.phone;
                              _errorMessage = null;
                            });
                          } else if (Navigator.canPop(context)) {
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentStep == AuthStep.phone
                          ? _buildPhoneStep(context, lang)
                          : _buildOtpStep(context, lang),
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

  /// Step 1: Name and Phone Number Input with "Send OTP"
  Widget _buildPhoneStep(BuildContext context, String lang) {
    return Column(
      key: const ValueKey("step_phone"),
      children: [
        const SizedBox(height: 10),

        // 1. Pramaan Brand Logo Image
        const _PramaanLogoWidget(),

        const SizedBox(height: 20),

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
            fontSize: lang == 'en' ? 26 : 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF133E2B),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppTranslations.tr(
            lang,
            "login_with_phone_subtitle",
            _getLocalizedLoginSubtitle(lang),
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 24),

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

        // 4. Mobile Number Input Field (With +91 Country Badge)
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
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              prefixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: Icon(
                      Icons.smartphone_rounded,
                      color: Color(0xFF1B6B43),
                      size: 24,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "+91",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 80,
                minHeight: 48,
              ),
              hintText: _getPhoneHint(lang),
              hintStyle: const TextStyle(
                fontSize: 13.5,
                letterSpacing: 0,
                color: Color(0xFF94A3B8),
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

        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // 5. Action Button: Send Verification OTP
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSendOtp,
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
                        AppTranslations.tr(
                          lang,
                          "send_otp_btn",
                          _getSendOtpLabel(lang),
                        ),
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

        const SizedBox(height: 24),
      ],
    );
  }

  /// Step 2: 6-Digit OTP Input, Countdown Timer & Verify Button
  Widget _buildOtpStep(BuildContext context, String lang) {
    final displayPhone = _normalizedPhone.isNotEmpty
        ? _getMaskedPhone(_normalizedPhone)
        : _getMaskedPhone(_phoneController.text);

    return Column(
      key: const ValueKey("step_otp"),
      children: [
        const SizedBox(height: 10),

        // 1. Pramaan Brand Logo Image
        const _PramaanLogoWidget(),

        const SizedBox(height: 20),

        // 2. Title Section
        Text(
          AppTranslations.tr(
            lang,
            "enter_otp_title",
            _getLocalizedOtpTitle(lang),
          ),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: lang == 'en' ? 24 : 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF133E2B),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "${AppTranslations.tr(lang, "otp_sent_to_desc", "We sent a 6-digit verification code to")}\n$displayPhone",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),

        const SizedBox(height: 28),

        // 3. 6-Digit Individual OTP Inputs
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            final isFilled = _otpControllers[index].text.isNotEmpty;
            return SizedBox(
              width: 46,
              height: 54,
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey ==
                          LogicalKeyboardKey.backspace) {
                    if (_otpControllers[index].text.isEmpty && index > 0) {
                      _otpControllers[index - 1].clear();
                      _otpFocusNodes[index - 1].requestFocus();
                      setState(() {});
                    }
                  }
                },
                child: TextField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6, // allows multi-digit paste into any box
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    counterText: "",
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    filled: true,
                    fillColor: isFilled
                        ? const Color(0xFFF0FDF4)
                        : Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isFilled
                            ? const Color(0xFF166534)
                            : const Color(0xFFCBD5E1),
                        width: isFilled ? 1.8 : 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1B6B43),
                        width: 2.2,
                      ),
                    ),
                  ),
                  onChanged: (val) => _onOtpDigitChanged(index, val),
                ),
              ),
            );
          }),
        ),

        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // 4. Action Button: Verify OTP & Enter Farm
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: (!_isOtpComplete || _isLoading)
                ? null
                : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B6B43),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              disabledForegroundColor: const Color(0xFF94A3B8),
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
                      const Icon(
                        Icons.verified_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppTranslations.tr(
                          lang,
                          "verify_otp_btn",
                          _getVerifyOtpLabel(lang),
                        ),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 18),

        // 5. Resend OTP Countdown / Action & Change Phone Button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_resendCountdown > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "${AppTranslations.tr(lang, "resend_otp_in", "Resend OTP in")} ${_resendCountdown}s",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _isLoading ? null : _handleResendOtp,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    AppTranslations.tr(
                      lang,
                      "resend_otp_btn",
                      _getResendOtpLabel(lang),
                    ),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B6B43),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // 6. Change Phone Number Link
        TextButton.icon(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _currentStep = AuthStep.phone;
                    _errorMessage = null;
                  });
                },
          icon: const Icon(
            Icons.edit_note_rounded,
            size: 18,
            color: Color(0xFF64748B),
          ),
          label: Text(
            AppTranslations.tr(
              lang,
              "change_phone_number",
              "Change Mobile Number",
            ),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
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

  String _getLocalizedOtpTitle(String lang) {
    switch (lang) {
      case 'mr':
        return "ओटीपी पडताळणी";
      case 'hi':
        return "ओटीपी सत्यापन";
      case 'pa':
        return "OTP ਪੁਸ਼ਟੀਕਰਨ";
      default:
        return "OTP Verification";
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

  String _getSendOtpLabel(String lang) {
    switch (lang) {
      case 'mr':
        return "ओटीपी पाठवा";
      case 'hi':
        return "ओटीपी भेजें";
      case 'pa':
        return "OTP ਭੇਜੋ";
      default:
        return "Send Verification OTP";
    }
  }

  String _getVerifyOtpLabel(String lang) {
    switch (lang) {
      case 'mr':
        return "ओटीपी तपासा आणि पुढे जा";
      case 'hi':
        return "ओटीपी सत्यापित करें";
      case 'pa':
        return "OTP ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ";
      default:
        return "Verify OTP & Enter Farm";
    }
  }

  String _getResendOtpLabel(String lang) {
    switch (lang) {
      case 'mr':
        return "ओटीपी पुन्हा पाठवा";
      case 'hi':
        return "ओटीपी पुनः भेजें";
      case 'pa':
        return "ਦੁਬਾਰਾ OTP ਭੇਜੋ";
      default:
        return "Resend OTP";
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
