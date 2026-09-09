import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/auth_provider.dart';
import '../core/providers/evidence_provider.dart';
import '../core/localization/app_translations.dart';
import '../core/services/api_service.dart';
import '../widgets/custom_bottom_nav.dart';

class CropCameraScreen extends StatefulWidget {
  const CropCameraScreen({super.key});

  @override
  State<CropCameraScreen> createState() => _CropCameraScreenState();
}

class _CropCameraScreenState extends State<CropCameraScreen> {
  static const MethodChannel _speechChannel = MethodChannel(
    'com.pramaan.app/speech',
  );

  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();

  XFile? _capturedFile;
  Uint8List? _capturedImageBytes;
  bool _isAnalyzing = false;
  bool _isSpeaking = false;
  String _selectedCrop = "Auto-Detect";
  int _presetIndex = 0;
  Map<String, dynamic>? _diagnosisResult;

  final List<Map<String, String>> _presetSamples = [
    {
      "title": "Wheat Foliage (Stripe Rust / Yellow Rust)",
      "url":
          "https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=800&auto=format&fit=crop&q=80",
      "crop": "Wheat (गेहूं)",
    },
    {
      "title": "Cotton Field (Whitefly / Boll Stage)",
      "url":
          "https://images.unsplash.com/photo-1530836369250-ef72a3f5cda8?w=800&auto=format&fit=crop&q=80",
      "crop": "Cotton (कपास)",
    },
    {
      "title": "Tomato Early Blight Lesions",
      "url":
          "https://images.unsplash.com/photo-1592841200221-a6898f307baa?w=800&auto=format&fit=crop&q=80",
      "crop": "Tomato (टमाटर)",
    },
    {
      "title": "Chilli Leaf Curl & Thrips Infestation",
      "url":
          "https://images.unsplash.com/photo-1588252303782-cb80119abd6d?w=800&auto=format&fit=crop&q=80",
      "crop": "Chilli (हरी मिर्च)",
    },
  ];

  @override
  void initState() {
    super.initState();
    _speechChannel.setMethodCallHandler(_handleNativeSpeechCallback);
  }

  @override
  void dispose() {
    if (_isSpeaking) {
      try {
        _speechChannel.invokeMethod('stopSpeaking');
      } catch (_) {}
    }
    _speechChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<dynamic> _handleNativeSpeechCallback(MethodCall call) async {
    if (!mounted) return null;
    if (call.method == 'onTtsStart') {
      setState(() => _isSpeaking = true);
    } else if (call.method == 'onTtsDone') {
      setState(() => _isSpeaking = false);
    }
    return null;
  }

  Future<void> _takePhoto(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedFile = photo;
          _capturedImageBytes = bytes;
          _diagnosisResult = null;
        });
        _analyzeCurrentPhoto();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Camera error: $e"),
            backgroundColor: AppColors.flaggedRed,
          ),
        );
      }
    }
  }

  void _analyzeCurrentPhoto() async {
    setState(() {
      _isAnalyzing = true;
      _diagnosisResult = null;
    });

    String? base64Str;
    if (_capturedImageBytes != null) {
      base64Str = base64Encode(_capturedImageBytes!);
    }

    try {
      String cropHint;
      if (_selectedCrop.contains("Auto-Detect")) {
        if (_capturedFile == null) {
          // User is inspecting a preset sample
          cropHint = _presetSamples[_presetIndex]['crop']!;
        } else {
          cropHint = "Auto-Detect";
        }
      } else {
        cropHint = _selectedCrop;
      }

      final result = await _api.analyzeVision(base64Str, cropHint);
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _diagnosisResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _saveEvidence() async {
    if (_diagnosisResult == null) return;
    final evProv = Provider.of<EvidenceProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final lang = authProv.selectedLanguage;

    final detectedCrop = _diagnosisResult!['crop_detected'] ?? _selectedCrop;
    final disease = _diagnosisResult!['disease_detected'] ?? 'Crop Foliar Scan';
    final severity = _diagnosisResult!['severity_level'] ?? 'Normal';
    final chemical =
        _diagnosisResult!['recommended_active_ingredient'] ??
        'Standard Foliar Treatment';

    final cropClean = _getLocalizedCropName(detectedCrop.toString(), lang);
    final diseaseClean = _getLocalizedDiseaseTitle(disease.toString(), lang);

    await evProv.addEvidence(
      title: "Crop Scan: $cropClean • $diseaseClean",
      description:
          "$diseaseClean identified on $cropClean ($severity severity). Recommendation: $chemical.",
      evidenceType: 'CROP_IMAGE',
      mediaUrl: _capturedFile?.path ?? _presetSamples[_presetIndex]['url'],
      productName: chemical,
    );

    if (mounted) {
      String successMsg = "$cropClean diagnostic evidence sealed & saved to Farm Journal!";
      if (lang == 'hi') {
        successMsg = "$cropClean की जांच रिपोर्ट डायरी में सुरक्षित कर ली गई है!";
      } else if (lang == 'mr') {
        successMsg = "$cropClean ची तपासणी नोंद डायरीत जतन करण्यात आली!";
      } else if (lang == 'pa') {
        successMsg = "$cropClean ਦੀ ਜਾਂਚ ਰਿਪੋਰਟ ਡਾਇਰੀ ਵਿੱਚ ਸੁਰੱਖਿਅਤ ਹੋ ਗਈ!";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(successMsg),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _toggleSpeakDiagnosis(String lang) async {
    if (_isSpeaking) {
      try {
        await _speechChannel.invokeMethod('stopSpeaking');
      } catch (_) {}
      setState(() => _isSpeaking = false);
      return;
    }

    if (_diagnosisResult == null) return;
    final res = _diagnosisResult!;
    final rawCrop = res['crop_detected']?.toString() ?? _selectedCrop;
    final rawDisease = res['disease_detected']?.toString() ?? 'Disease';
    final rawSpray = res['recommended_active_ingredient']?.toString() ?? 'Treatment';

    final cropClean = _getLocalizedCropName(rawCrop, lang);
    final diseaseClean = _getLocalizedDiseaseTitle(rawDisease, lang);
    final dosageInfo = _getLocalizedDosageAndChemical(rawCrop, rawDisease, rawSpray, lang);

    String speech = '';
    switch (lang) {
      case 'mr':
        speech = 'पीक तपासणी निष्कर्ष: पिकाचे नाव $cropClean. रोग किंवा कीड $diseaseClean. शिफारस केलेला उपाय: ${dosageInfo['main']}. पुढील तीन दिवसात सकाळी शांत हवेत पानांच्या दोन्ही बाजूंनी फवारणी करा.';
        break;
      case 'pa':
        speech = 'ਫਸਲ ਜਾਂਚ ਰਿਪੋਰਟ: ਫਸਲ $cropClean. ਰੋਗ ਜਾਂ ਕੀੜਾ $diseaseClean. ਸਿਫਾਰਸ਼ ਕੀਤੀ ਸਪਰੇਅ: ${dosageInfo['main']}. ਅਗਲੇ ਤਿੰਨ ਦਿਨਾਂ ਦੇ ਅੰਦਰ ਸਵੇਰੇ ਸ਼ਾਂਤ ਮੌਸਮ ਵਿੱਚ ਪੱਤਿਆਂ ਦੇ ਦੋਵੇਂ ਪਾਸੇ ਸਪਰੇਅ ਕਰੋ.';
        break;
      case 'en':
        speech = 'Crop Doctor Advice: Identified $diseaseClean on $cropClean. Recommended action: ${dosageInfo['main']}. Apply within 3 days in the calm morning covering both sides of leaves.';
        break;
      case 'hi':
      default:
        speech = 'फसल डॉक्टर सलाह: फसल $cropClean पर $diseaseClean की पहचान हुई है। अनुशंसित उपाय: ${dosageInfo['main']}। अगले ३ दिन में सुबह शांत मौसम में पत्तों के दोनों तरफ अच्छी तरह स्प्रे करें।';
        break;
    }

    try {
      setState(() => _isSpeaking = true);
      final locale = lang == 'mr'
          ? 'mr-IN'
          : (lang == 'pa'
              ? 'pa-IN'
              : (lang == 'en' ? 'en-IN' : 'hi-IN'));

      await _speechChannel.invokeMethod('speak', {
        'text': speech,
        'language': locale,
      });
    } catch (e) {
      debugPrint('[CropCamera TTS] speak error: $e');
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final lang = authProv.selectedLanguage;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 22),
          onPressed: () {
            if (_diagnosisResult != null) {
              setState(() => _diagnosisResult = null);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          AppTranslations.tr(lang, "crop_doctor_title", "Crop Doctor AI"),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          // Language Switcher Badge Button
          InkWell(
            onTap: () => AppTranslations.showLanguageSelectorModal(
              context,
              lang,
              (newLang) => authProv.setLanguage(newLang),
            ),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF047857),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    lang.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF047857),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _diagnosisResult != null
          ? _buildFarmerDiagnosisResultView(lang)
          : _buildScannerCameraView(lang),
      bottomNavigationBar: _diagnosisResult == null
          ? const CustomBottomNav(currentIndex: -1)
          : null,
    );
  }

  // ==========================================================
  // VIEW 1: FARMER-FRIENDLY DIAGNOSIS RESULT PAGE (Matching SS2)
  // ==========================================================
  Widget _buildFarmerDiagnosisResultView(String lang) {
    final activePreset = _presetSamples[_presetIndex];
    final res = _diagnosisResult!;

    final rawCrop = res['crop_detected']?.toString() ?? _selectedCrop;
    final cropClean = _getLocalizedCropName(rawCrop, lang);
    final rawDisease = res['disease_detected']?.toString() ?? 'Yellow Rust';
    final diseaseTitle = _getLocalizedDiseaseTitle(rawDisease, lang);
    final diseaseCategory = _getLocalizedDiseaseCategory(rawDisease, res['health_status']?.toString(), lang);
    final confidence = ((res['confidence'] ?? 0.85) * 100).toInt();
    final dosageInfo = _getLocalizedDosageAndChemical(rawCrop, rawDisease, res['recommended_active_ingredient']?.toString(), lang);

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Crop Selector Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.eco_rounded,
                          color: Color(0xFF047857),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getLocalizedCropLabel(lang),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            cropClean,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          setState(() => _diagnosisResult = null);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getLocalizedChangeCropText(lang),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Main Diagnostic Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Disease Title & Match Tag
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  diseaseTitle,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  diseaseCategory,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.eco_rounded,
                                  color: Color(0xFF047857),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "$confidence% ${_getLocalizedMatchText(lang)}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Scanned Leaf Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: _capturedImageBytes != null
                              ? kIsWeb
                                  ? Image.memory(_capturedImageBytes!, fit: BoxFit.cover)
                                  : Image.file(File(_capturedFile!.path), fit: BoxFit.cover)
                              : Image.network(
                                  activePreset['url']!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, _, _) => Container(
                                    color: const Color(0xFFECFDF5),
                                    child: const Center(
                                      child: Icon(Icons.eco_rounded, color: Color(0xFF047857), size: 48),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Audio Advice Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isSpeaking ? const Color(0xFFDCFCE7) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isSpeaking ? const Color(0xFF16A34A) : const Color(0xFFA7F3D0),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFF047857),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isSpeaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isSpeaking
                                        ? (lang == 'hi'
                                            ? 'आवाज चल रही है...'
                                            : (lang == 'mr'
                                                ? 'आवाज सुरू आहे...'
                                                : (lang == 'pa'
                                                    ? 'ਆਵਾਜ਼ ਚੱਲ ਰਹੀ ਹੈ...'
                                                    : 'Speaking aloud...')))
                                        : _getLocalizedListenAdviceTitle(lang),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _getLocalizedListenAdviceSubtitle(lang),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => _toggleSpeakDiagnosis(lang),
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _isSpeaking ? const Color(0xFFDC2626) : const Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isSpeaking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                  color: _isSpeaking ? Colors.white : const Color(0xFF047857),
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // What to do? Action Plan Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAF9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD1FAE5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.eco_rounded, color: Color(0xFF047857), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _getLocalizedWhatToDoHeader(lang),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Step 1: Spray Chemical & Water Ratio
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.sanitizer_rounded,
                                    color: Color(0xFF047857),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dosageInfo['main']!,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dosageInfo['sub']!,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Step 2: Leaf Coverage Method
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.eco_outlined,
                                    color: Color(0xFF047857),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _getLocalizedTechniqueText(lang),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Step 3: Timing & Weather Condition
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.wb_sunny_rounded,
                                    color: Color(0xFFD97706),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _getLocalizedTimingText(res['urgency_days'], lang),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Positive Outcome Protection Banner
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4EA),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF047857),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getLocalizedProtectionText(lang),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Save in My Journal Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saveEvidence,
                    icon: const Icon(Icons.bookmark_add_rounded, size: 20),
                    label: Text(
                      _getLocalizedSaveJournalText(lang),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // 4. Subtle Farm Landscape Footer Art
          _buildFarmLandscapeFooter(),
        ],
      ),
    );
  }

  // ==========================================================
  // VIEW 2: CAMERA SCANNER & PRESET SAMPLES VIEW
  // ==========================================================
  Widget _buildScannerCameraView(String lang) {
    final activePreset = _presetSamples[_presetIndex];

    final targetCrops = [
      {"label": "Auto-Detect", "icon": Icons.eco_rounded, "display": _getLocalizedCropName("Auto-Detect", lang)},
      {"label": "Wheat", "emoji": "🌾", "display": _getLocalizedCropName("Wheat", lang)},
      {"label": "Cotton", "emoji": "🌿", "display": _getLocalizedCropName("Cotton", lang)},
      {"label": "Other", "icon": Icons.eco_rounded, "display": _getLocalizedCropName("Other", lang)},
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Target Crop Horizontal Selector
          Row(
            children: [
              Text(
                _getLocalizedTargetCropLabel(lang),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: targetCrops.map((tc) {
                      final isSel = _selectedCrop == tc['label'] ||
                          (_selectedCrop.contains("Auto-Detect") && tc['label'] == "Auto-Detect");
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCrop = tc['label'] as String;
                            });
                            if (_capturedImageBytes != null || _diagnosisResult != null) {
                              _analyzeCurrentPhoto();
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF047857) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSel ? const Color(0xFF047857) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (tc['emoji'] != null)
                                  Text(tc['emoji'] as String, style: const TextStyle(fontSize: 12))
                                else if (tc['icon'] != null)
                                  Icon(
                                    tc['icon'] as IconData,
                                    size: 14,
                                    color: isSel ? Colors.white : const Color(0xFF047857),
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  tc['display'] as String,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Camera Viewfinder Box
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Leaf Image Canvas
                  if (_capturedImageBytes != null)
                    kIsWeb
                        ? Image.memory(_capturedImageBytes!, fit: BoxFit.cover)
                        : Image.file(File(_capturedFile!.path), fit: BoxFit.cover)
                  else
                    Image.network(
                      activePreset['url']!,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF047857),
                          ),
                        );
                      },
                    ),

                  // Center White Focus Target Overlay
                  Center(
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  if (_isAnalyzing)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFF10B981),
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getLocalizedDiagnosingText(lang),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom Floating Instruction Pill
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getLocalizedAlignCameraText(lang),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Try Sample Banner
          InkWell(
            onTap: () {
              setState(() {
                _capturedFile = null;
                _capturedImageBytes = null;
                _presetIndex = (_presetIndex + 1) % _presetSamples.length;
                _selectedCrop = _presetSamples[_presetIndex]['crop']!;
                _diagnosisResult = null;
              });
              _analyzeCurrentPhoto();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: Color(0xFFD97706),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _capturedFile != null
                          ? _getLocalizedCapturedPhotoText(lang)
                          : _getLocalizedSampleTitle(_presetIndex, lang),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "${_getLocalizedTrySampleText(lang)} >",
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons Row (Take Photo, Gallery, Refresh)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _takePhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text(
                      _getLocalizedTakePhotoText(lang),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () => _takePhoto(ImageSource.gallery),
                    icon: const Icon(Icons.image_rounded, size: 18, color: Color(0xFF047857)),
                    label: Text(
                      _getLocalizedGalleryText(lang),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Color(0xFF047857),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF047857), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: IconButton(
                  onPressed: _isAnalyzing ? null : _analyzeCurrentPhoto,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF047857),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Crop Doctor AI Guide Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.eco_rounded,
                      color: Color(0xFF047857),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppTranslations.tr(lang, "crop_doctor_title", "Crop Doctor AI"),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _getLocalizedGuideText(lang),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF1E293B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Recent Analyses Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getLocalizedRecentAnalysesTitle(lang),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/evidence_review'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    _getLocalizedViewAllText(lang),
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

          // Recent Analyses List
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildAnalysisItem(
                  imageUrl: "https://images.unsplash.com/photo-1574943320219-553eb213f72d?w=800&auto=format&fit=crop&q=80",
                  title: _getLocalizedRecentItemTitle(0, lang),
                  subtitle: _getLocalizedRecentConfidence(96, lang),
                  time: _getLocalizedDaysAgo(2, lang),
                  lang: lang,
                  onTap: () {
                    setState(() {
                      _presetIndex = 0;
                      _selectedCrop = "Wheat";
                    });
                    _analyzeCurrentPhoto();
                  },
                ),
                const Divider(height: 1, indent: 64, endIndent: 16, color: Color(0xFFF1F5F9)),
                _buildAnalysisItem(
                  imageUrl: "https://images.unsplash.com/photo-1530836369250-ef72a3f5cda8?w=800&auto=format&fit=crop&q=80",
                  title: _getLocalizedRecentItemTitle(1, lang),
                  subtitle: _getLocalizedRecentConfidence(92, lang),
                  time: _getLocalizedDaysAgo(5, lang),
                  lang: lang,
                  onTap: () {
                    setState(() {
                      _presetIndex = 1;
                      _selectedCrop = "Cotton";
                    });
                    _analyzeCurrentPhoto();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem({
    required String imageUrl,
    required String title,
    required String subtitle,
    required String time,
    required String lang,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (ctx, _, _) => Container(
                  width: 44,
                  height: 44,
                  color: const Color(0xFFECFDF5),
                  child: const Icon(Icons.eco_rounded, color: Color(0xFF047857)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF047857),
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _getLocalizedIdentifiedBadge(lang),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // MULTILINGUAL LOCALIZATION HELPERS (HI, MR, PA, EN)
  // ==========================================================

  String _getLocalizedCropLabel(String lang) {
    switch (lang) {
      case 'mr':
        return 'पीक:';
      case 'pa':
        return 'ਫਸਲ:';
      case 'hi':
        return 'फसल:';
      case 'en':
      default:
        return 'Crop:';
    }
  }

  String _getLocalizedCropName(String raw, String lang) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains("wheat") || lower.contains("गेहूं") || lower.contains("गहू") || lower.contains("ਕਣਕ")) {
      switch (lang) {
        case 'mr':
          return 'गहू (Wheat)';
        case 'pa':
          return 'ਕਣਕ (Wheat)';
        case 'hi':
          return 'गेहूं (Wheat)';
        case 'en':
        default:
          return 'Wheat';
      }
    }
    if (lower.contains("cotton") || lower.contains("कपास") || lower.contains("कापूस") || lower.contains("ਨਰਮਾ")) {
      switch (lang) {
        case 'mr':
          return 'कापूस (Cotton)';
        case 'pa':
          return 'ਨਰਮਾ / ਕਪਾਹ (Cotton)';
        case 'hi':
          return 'कपास (Cotton)';
        case 'en':
        default:
          return 'Cotton';
      }
    }
    if (lower.contains("tomato") || lower.contains("टमाटर") || lower.contains("टोमॅटो") || lower.contains("ਟਮਾਟਰ")) {
      switch (lang) {
        case 'mr':
          return 'टोमॅटो (Tomato)';
        case 'pa':
          return 'ਟਮਾਟਰ (Tomato)';
        case 'hi':
          return 'टमाटर (Tomato)';
        case 'en':
        default:
          return 'Tomato';
      }
    }
    if (lower.contains("chilli") || lower.contains("chili") || lower.contains("मिर्च") || lower.contains("मिरची") || lower.contains("ਮਿਰਚ")) {
      switch (lang) {
        case 'mr':
          return 'हिरवी मिरची (Chilli)';
        case 'pa':
          return 'ਹਰੀ ਮਿਰਚ (Chilli)';
        case 'hi':
          return 'हरी मिर्च (Chilli)';
        case 'en':
        default:
          return 'Chilli';
      }
    }
    if (lower.contains("paddy") || lower.contains("rice") || lower.contains("धान") || lower.contains("भात") || lower.contains("ਝੋਨਾ")) {
      switch (lang) {
        case 'mr':
          return 'भात / धान (Paddy)';
        case 'pa':
          return 'ਝੋਨਾ (Paddy/Rice)';
        case 'hi':
          return 'धान (Paddy/Rice)';
        case 'en':
        default:
          return 'Paddy (Rice)';
      }
    }
    if (lower.contains("potato") || lower.contains("आलू") || lower.contains("बटाटा") || lower.contains("ਆਲੂ")) {
      switch (lang) {
        case 'mr':
          return 'बटाटा (Potato)';
        case 'pa':
          return 'ਆਲੂ (Potato)';
        case 'hi':
          return 'आलू (Potato)';
        case 'en':
        default:
          return 'Potato';
      }
    }
    if (lower.contains("mustard") || lower.contains("सरसों") || lower.contains("मोहरी") || lower.contains("ਸਰ੍ਹੋਂ")) {
      switch (lang) {
        case 'mr':
          return 'मोहरी (Mustard)';
        case 'pa':
          return 'ਸਰ੍ਹੋਂ (Mustard)';
        case 'hi':
          return 'सरसों (Mustard)';
        case 'en':
        default:
          return 'Mustard';
      }
    }
    if (lower.contains("auto") || lower.contains("detect") || lower.contains("स्वचालित")) {
      switch (lang) {
        case 'mr':
          return 'स्वयंचलित शोध (Auto-Detect)';
        case 'pa':
          return 'ਆਟੋ-ਡਿਟੈਕਟ (Auto-Detect)';
        case 'hi':
          return 'स्वचालित पहचान (Auto-Detect)';
        case 'en':
        default:
          return 'Auto-Detect';
      }
    }
    if (lower.contains("other") || lower.contains("अन्य")) {
      switch (lang) {
        case 'mr':
          return 'इतर पीक';
        case 'pa':
          return 'ਹੋਰ ਫਸਲ';
        case 'hi':
          return 'अन्य फसल';
        case 'en':
        default:
          return 'Other Crop';
      }
    }

    if (raw.contains("(")) {
      return raw.split("(")[0].trim();
    }
    return raw.trim();
  }

  String _getLocalizedChangeCropText(String lang) {
    switch (lang) {
      case 'mr':
        return 'पीक बदला';
      case 'pa':
        return 'ਫਸਲ ਬਦਲੋ';
      case 'hi':
        return 'फसल बदलें';
      case 'en':
      default:
        return 'Change';
    }
  }

  String _getLocalizedDiseaseTitle(String raw, String lang) {
    final lower = raw.toLowerCase().trim();
    if (lower.contains("stripe rust") || lower.contains("yellow rust") || lower.contains("रतुआ") || lower.contains("तांबेरा") || lower.contains("ਕੁੰਗੀ")) {
      switch (lang) {
        case 'mr':
          return 'पिवळा तांबेरा (Yellow Rust)';
        case 'pa':
          return 'ਪੀਲੀ ਕੁੰਗੀ (Yellow Rust)';
        case 'hi':
          return 'पीला रतुआ (Yellow Rust)';
        case 'en':
        default:
          return 'Yellow Rust (Stripe Rust)';
      }
    }
    if (lower.contains("whitefly") || lower.contains("सफेद मक्खी") || lower.contains("पांढरी माशी") || lower.contains("ਚਿੱਟੀ ਮੱਖੀ")) {
      switch (lang) {
        case 'mr':
          return 'पांढरी माशी (Whitefly)';
        case 'pa':
          return 'ਚਿੱਟੀ ਮੱਖੀ (Whitefly)';
        case 'hi':
          return 'सफेद मक्खी (Whitefly)';
        case 'en':
        default:
          return 'Whitefly Infestation';
      }
    }
    if (lower.contains("pink bollworm") || lower.contains("गुलाबी")) {
      switch (lang) {
        case 'mr':
          return 'गुलाबी बोंडअळी (Pink Bollworm)';
        case 'pa':
          return 'ਗੁਲਾਬੀ ਸੁੰਡੀ (Pink Bollworm)';
        case 'hi':
          return 'गुलाबी सुंडी (Pink Bollworm)';
        case 'en':
        default:
          return 'Pink Bollworm';
      }
    }
    if (lower.contains("early blight") || lower.contains("अगेती झुलसा")) {
      switch (lang) {
        case 'mr':
          return 'लवकर येणारा करपा (Early Blight)';
        case 'pa':
          return 'ਅਗੇਤਾ ਝੁਲਸ ਰੋਗ (Early Blight)';
        case 'hi':
          return 'अगेती झुलसा (Early Blight)';
        case 'en':
        default:
          return 'Early Blight';
      }
    }
    if (lower.contains("late blight") || lower.contains("पछेती झुलसा")) {
      switch (lang) {
        case 'mr':
          return 'उशिरा येणारा करपा (Late Blight)';
        case 'pa':
          return 'ਪਛੇਤਾ ਝੁਲਸ ਰੋਗ (Late Blight)';
        case 'hi':
          return 'पछेती झुलसा (Late Blight)';
        case 'en':
        default:
          return 'Late Blight';
      }
    }
    if (lower.contains("leaf curl") || lower.contains("पर्ण कुंचन") || lower.contains("चुरडा") || lower.contains("ਮਰੋੜ")) {
      switch (lang) {
        case 'mr':
          return 'पान चुरडा (Leaf Curl Virus)';
        case 'pa':
          return 'ਪੱਤਾ ਮਰੋੜ ਰੋਗ (Leaf Curl Virus)';
        case 'hi':
          return 'पर्ण कुंचन (Leaf Curl Virus)';
        case 'en':
        default:
          return 'Leaf Curl Virus';
      }
    }
    if (lower.contains("sheath blight") || lower.contains("शीथ")) {
      switch (lang) {
        case 'mr':
          return 'शेंड करपा (Sheath Blight)';
        case 'pa':
          return 'ਸ਼ੀਥ ਬਲਾਈਟ (Sheath Blight)';
        case 'hi':
          return 'शीथ ब्लाइट (Sheath Blight)';
        case 'en':
        default:
          return 'Sheath Blight';
      }
    }
    if (lower.contains("blast") || lower.contains("ब्लास्ट")) {
      switch (lang) {
        case 'mr':
          return 'ब्लास्ट / करपा रोग (Blast)';
        case 'pa':
          return 'ਬਲਾਸਟ ਰੋਗ (Blast Disease)';
        case 'hi':
          return 'ब्लास्ट रोग (Blast Disease)';
        case 'en':
        default:
          return 'Blast Disease';
      }
    }
    if (lower.contains("powdery mildew") || lower.contains("छछिया") || lower.contains("भुरी")) {
      switch (lang) {
        case 'mr':
          return 'भुरी रोग (Powdery Mildew)';
        case 'pa':
          return 'ਚਿੱਟਾ ਧੱਬਾ ਰੋਗ (Powdery Mildew)';
        case 'hi':
          return 'चूर्णिल आसिता / छछिया (Powdery Mildew)';
        case 'en':
        default:
          return 'Powdery Mildew';
      }
    }
    if (lower.contains("healthy") || lower.contains("स्वस्थ") || lower.contains("निरोगी")) {
      switch (lang) {
        case 'mr':
          return 'निरोगी पीक (Healthy Crop)';
        case 'pa':
          return 'ਤੰਦਰੁਸਤ ਫਸਲ (Healthy Crop)';
        case 'hi':
          return 'स्वस्थ फसल (Healthy Crop)';
        case 'en':
        default:
          return 'Healthy Crop';
      }
    }

    return raw;
  }

  String _getLocalizedDiseaseCategory(String rawDisease, String? healthStatus, String lang) {
    final lower = rawDisease.toLowerCase();
    if (lower.contains("rust") ||
        lower.contains("blight") ||
        lower.contains("rot") ||
        lower.contains("smut") ||
        lower.contains("spot") ||
        lower.contains("mildew") ||
        lower.contains("blast")) {
      switch (lang) {
        case 'mr':
          return 'बुरशीजन्य रोग';
        case 'pa':
          return 'ਉੱਲੀ ਰੋਗ';
        case 'hi':
          return 'फफूंद जनित रोग';
        case 'en':
        default:
          return 'Fungal disease';
      }
    }
    if (lower.contains("whitefly") ||
        lower.contains("thrips") ||
        lower.contains("bollworm") ||
        lower.contains("aphid") ||
        lower.contains("mite") ||
        lower.contains("borer") ||
        lower.contains("pest") ||
        lower.contains("सुंडी") ||
        lower.contains("माशी")) {
      switch (lang) {
        case 'mr':
          return 'किडीचा प्रादुर्भाव';
        case 'pa':
          return 'ਕੀੜਿਆਂ ਦਾ ਹਮਲਾ';
        case 'hi':
          return 'कीट का प्रकोप';
        case 'en':
        default:
          return 'Pest Infestation';
      }
    }
    if (lower.contains("curl") || lower.contains("mosaic") || lower.contains("virus")) {
      switch (lang) {
        case 'mr':
          return 'विषाणूजन्य रोग';
        case 'pa':
          return 'ਵਿਸ਼ਾਣੂ ਰੋਗ';
        case 'hi':
          return 'विषाणु जनित रोग';
        case 'en':
        default:
          return 'Viral disease';
      }
    }
    if (lower.contains("wilt") || lower.contains("canker") || lower.contains("bacterial")) {
      switch (lang) {
        case 'mr':
          return 'जिवाणू संसर्ग';
        case 'pa':
          return 'ਜੀਵਾਣੂ ਰੋਗ';
        case 'hi':
          return 'जीवाणु संक्रमण';
        case 'en':
        default:
          return 'Bacterial infection';
      }
    }

    switch (lang) {
      case 'mr':
        return 'पिकाची स्थिती';
      case 'pa':
        return 'ਫਸਲ ਦੀ ਸਥਿਤੀ';
      case 'hi':
        return 'पौधे की स्थिति';
      case 'en':
      default:
        return healthStatus ?? 'Plant Pathology';
    }
  }

  String _getLocalizedMatchText(String lang) {
    switch (lang) {
      case 'mr':
        return 'अचूकता';
      case 'pa':
        return 'ਮੇਲ';
      case 'hi':
        return 'सटीकता';
      case 'en':
      default:
        return 'match';
    }
  }

  String _getLocalizedListenAdviceTitle(String lang) {
    switch (lang) {
      case 'mr':
        return 'सल्ला ऐका';
      case 'pa':
        return 'ਸਲਾਹ ਸੁਣੋ';
      case 'hi':
        return 'सलाह सुनें';
      case 'en':
      default:
        return 'Listen to Advice';
    }
  }

  String _getLocalizedListenAdviceSubtitle(String lang) {
    switch (lang) {
      case 'mr':
        return 'पिकाच्या चांगल्या काळजीसाठी ऑडिओ ऐका';
      case 'pa':
        return 'ਫਸਲ ਦੀ ਬਿਹਤਰ ਦੇਖਭਾਲ ਲਈ ਆਡੀਓ ਸੁਣੋ';
      case 'hi':
        return 'फसल की बेहतर देखभाल के लिए ऑडियो सुनें';
      case 'en':
      default:
        return 'Listen to personalized guidance for your crop';
    }
  }

  String _getLocalizedWhatToDoHeader(String lang) {
    switch (lang) {
      case 'mr':
        return 'काय करावे? (उपाय योजना)';
      case 'pa':
        return 'ਕੀ ਕਰਨਾ ਹੈ? (ਸਪਰੇਅ ਯੋਜਨਾ)';
      case 'hi':
        return 'क्या करें? (सटीक उपाय)';
      case 'en':
      default:
        return 'What to do?';
    }
  }

  Map<String, String> _getLocalizedDosageAndChemical(
    String rawCrop,
    String rawDisease,
    String? rawSpray,
    String lang,
  ) {
    final lowerCrop = rawCrop.toLowerCase();
    final lowerDisease = rawDisease.toLowerCase();

    // 1. Wheat Yellow / Stripe Rust
    if (lowerCrop.contains("wheat") || lowerDisease.contains("rust") || lowerDisease.contains("रतुआ") || lowerDisease.contains("ਕੁੰਗੀ")) {
      switch (lang) {
        case 'mr':
          return {
            "main": "प्रोपिकोनाझोल (Propiconazole 25% EC) १ मिली प्रति लिटर पाणी",
            "sub": "प्रति एकर २०० लिटर पाण्यात मिसळून फवारणी करा.",
          };
        case 'pa':
          return {
            "main": "ਪ੍ਰੋਪੀਕੋਨਾਜ਼ੋਲ (Propiconazole 25% EC) 1 ਮਿ.ਲੀ. ਪ੍ਰਤੀ ਲੀਟਰ ਪਾਣੀ",
            "sub": "ਪ੍ਰਤੀ ਏਕੜ 200 ਲੀਟਰ ਪਾਣੀ ਵਿੱਚ ਮਿਲਾ ਕੇ ਛਿੜਕਾਅ ਕਰੋ।",
          };
        case 'hi':
          return {
            "main": "प्रोपिकोनाज़ोल (Propiconazole 25% EC) 1 मिली प्रति लीटर पानी",
            "sub": "प्रति एकड़ 200 लीटर साफ पानी में मिलाकर छिड़काव करें।",
          };
        case 'en':
        default:
          return {
            "main": "Use Propiconazole 25% EC 1 ml per litre of water",
            "sub": "Mix in 200 litres of water per acre.",
          };
      }
    }

    // 2. Cotton Whitefly / Bollworm
    if (lowerCrop.contains("cotton") || lowerDisease.contains("whitefly") || lowerDisease.contains("सफेद मक्खी") || lowerDisease.contains("ਮੱਖੀ")) {
      switch (lang) {
        case 'mr':
          return {
            "main": "पायरीप्रॉक्सीफेन (Pyriproxyfen 10% EC) २ मिली किंवा पेगासस १ ग्रॅम प्रति लिटर पाणी",
            "sub": "प्रति एकर २०० लिटर पाण्यात मिसळून फवारणी करा.",
          };
        case 'pa':
          return {
            "main": "ਪਾਈਰੀਪ੍ਰੋਕਸੀਫੇਨ (Pyriproxyfen 10% EC) 2 ਮਿ.ਲੀ. ਜਾਂ ਪੇਗਾਸਸ 1 ਗ੍ਰਾਮ ਪ੍ਰਤੀ ਲੀਟਰ ਪਾਣੀ",
            "sub": "ਪ੍ਰਤੀ ਏਕੜ 200 ਲੀਟਰ ਪਾਣੀ ਵਿੱਚ ਮਿਲਾ ਕੇ ਸਪਰੇਅ ਕਰੋ।",
          };
        case 'hi':
          return {
            "main": "पाइरीप्रॉक्सीफेन (Pyriproxyfen 10% EC) 2 मिली या पेगासस 1 ग्राम प्रति लीटर पानी",
            "sub": "प्रति एकड़ 200 लीटर साफ पानी में मिलाकर स्प्रे करें।",
          };
        case 'en':
        default:
          return {
            "main": "Use Pyriproxyfen 10% EC @ 2 ml or Pegasus @ 1 g per litre of water",
            "sub": "Mix in 200 litres of clean water per acre.",
          };
      }
    }

    // 3. Tomato Early/Late Blight
    if (lowerCrop.contains("tomato") || lowerDisease.contains("blight") || lowerDisease.contains("झुलसा") || lowerDisease.contains("करपा")) {
      switch (lang) {
        case 'mr':
          return {
            "main": "मॅन्कोझेब (Mancozeb 75% WP) २.५ ग्रॅम प्रति लिटर पाणी",
            "sub": "प्रति एकर २०० लिटर पाण्यात मिसळून फवारणी करा.",
          };
        case 'pa':
          return {
            "main": "ਮੈਨਕੋਜ਼ੇਬ (Mancozeb 75% WP) 2.5 ਗ੍ਰਾਮ ਪ੍ਰਤੀ ਲੀਟਰ ਪਾਣੀ",
            "sub": "ਪ੍ਰਤੀ ਏਕੜ 200 ਲੀਟਰ ਪਾਣੀ ਵਿੱਚ ਮਿਲਾ ਕੇ ਛਿੜਕਾਅ ਕਰੋ।",
          };
        case 'hi':
          return {
            "main": "मैनकोज़ेब (Mancozeb 75% WP) 2.5 ग्राम प्रति लीटर पानी",
            "sub": "प्रति एकड़ 200 लीटर साफ पानी में मिलाकर छिड़कें।",
          };
        case 'en':
        default:
          return {
            "main": "Use Mancozeb 75% WP @ 2.5 g per litre of water",
            "sub": "Mix in 200 litres of clean water per acre.",
          };
      }
    }

    // 4. Chilli Leaf Curl / Thrips
    if (lowerCrop.contains("chilli") || lowerCrop.contains("chili") || lowerDisease.contains("curl") || lowerDisease.contains("thrips") || lowerDisease.contains("मिरची")) {
      switch (lang) {
        case 'mr':
          return {
            "main": "फिप्रोनिल (Fipronil 5% SC) २ मिली किंवा इमिडाक्लोप्रिड ०.५ मिली प्रति लिटर पाणी",
            "sub": "प्रति एकर २०० लिटर पाण्यात मिसळून फवारणी करा.",
          };
        case 'pa':
          return {
            "main": "ਫਿਪਰੋਨਿਲ (Fipronil 5% SC) 2 ਮਿ.ਲੀ. ਜਾਂ ਇਮੀਡਾਕਲੋਪ੍ਰਿਡ 0.5 ਮਿ.ਲੀ. ਪ੍ਰਤੀ ਲੀਟਰ ਪਾਣੀ",
            "sub": "ਪ੍ਰਤੀ ਏਕੜ 200 ਲੀਟਰ ਪਾਣੀ ਵਿੱਚ ਮਿਲਾ ਕੇ ਛਿੜਕਾਅ ਕਰੋ।",
          };
        case 'hi':
          return {
            "main": "फिपरोनिल (Fipronil 5% SC) 2 मिली या इमिडाक्लोप्रिड 0.5 मिली प्रति लीटर पानी",
            "sub": "प्रति एकड़ 200 लीटर साफ पानी में मिलाकर छिड़कें।",
          };
        case 'en':
        default:
          return {
            "main": "Use Fipronil 5% SC @ 2 ml or Imidacloprid @ 0.5 ml per litre of water",
            "sub": "Mix in 200 litres of clean water per acre.",
          };
      }
    }

    // Fallback Generic Parsing
    String main = rawSpray ?? "Standard Treatment";
    String sub = "Mix in 200 litres of water per acre.";
    if (main.contains("(") && main.contains(")")) {
      final sIdx = main.indexOf("(");
      final eIdx = main.indexOf(")");
      sub = main.substring(sIdx + 1, eIdx).trim();
      main = main.substring(0, sIdx).trim();
    }
    return {"main": "Use $main", "sub": sub};
  }

  String _getLocalizedTechniqueText(String lang) {
    switch (lang) {
      case 'mr':
        return 'रोगाचा प्रादुर्भाव रोखण्यासाठी पानांच्या दोन्ही बाजूने (वर आणि खाली) व्यवस्थित फवारणी करा.';
      case 'pa':
        return 'ਬਿਮਾਰੀ ਨੂੰ ਰੋਕਣ ਲਈ ਪੱਤਿਆਂ ਦੇ ਦੋਵੇਂ ਪਾਸੇ (ਉੱਪਰ ਅਤੇ ਹੇਠਾਂ) ਚੰਗੀ ਤਰ੍ਹਾਂ ਸਪਰੇਅ ਕਰੋ।';
      case 'hi':
        return 'पत्तों के दोनों तरफ (ऊपर और नीचे) अच्छी तरह स्प्रे करें ताकि रोग पूरी तरह रुके।';
      case 'en':
      default:
        return 'Spray on both sides of the leaves for complete foliar coverage.';
    }
  }

  String _getLocalizedTimingText(dynamic urgencyDays, String lang) {
    final days = urgencyDays?.toString() ?? '3';
    switch (lang) {
      case 'mr':
        return 'पुढील $days दिवसांत सकाळी शांत व निरभ्र हवेत फवारणी करा.';
      case 'pa':
        return 'ਅਗਲੇ $days ਦਿਨਾਂ ਦੇ ਅੰਦਰ ਸਵੇਰੇ ਸ਼ਾਂਤ ਮੌਸਮ ਵਿੱਚ ਸਪਰੇਅ ਕਰੋ।';
      case 'hi':
        return 'अगले $days दिनों के भीतर सुबह शांत मौसम में छिड़काव करें।';
      case 'en':
      default:
        return 'Apply within $days days in calm morning conditions.';
    }
  }

  String _getLocalizedProtectionText(String lang) {
    switch (lang) {
      case 'mr':
        return 'वेळेवर फवारणी केल्याने पिकाचे उत्पादन १००% सुरक्षित राहील.';
      case 'pa':
        return 'ਸਮੇਂ ਸਿਰ ਸਪਰੇਅ ਕਰਨ ਨਾਲ ਫਸਲ ਦਾ ਝਾੜ 100% ਸੁਰੱਖਿਅਤ ਰਹੇਗਾ।';
      case 'hi':
        return 'समय पर स्प्रे करने से फसल की पैदावार 100% सुरक्षित रहेगी।';
      case 'en':
      default:
        return 'Timely spraying will protect 100% of your crop yield.';
    }
  }

  String _getLocalizedSaveJournalText(String lang) {
    switch (lang) {
      case 'mr':
        return 'माझ्या डायरीत जतन करा';
      case 'pa':
        return 'ਮੇਰੀ ਡਾਇਰੀ ਵਿੱਚ ਸੁਰੱਖਿਅਤ ਕਰੋ';
      case 'hi':
        return 'मेरी डायरी में सुरक्षित करें';
      case 'en':
      default:
        return 'Save in My Journal';
    }
  }

  String _getLocalizedTargetCropLabel(String lang) {
    switch (lang) {
      case 'mr':
        return 'लक्ष्य पीक:';
      case 'pa':
        return 'ਟਾਰਗੇਟ ਫਸਲ:';
      case 'hi':
        return 'टारगेट फसल:';
      case 'en':
      default:
        return 'Target Crop:';
    }
  }

  String _getLocalizedDiagnosingText(String lang) {
    switch (lang) {
      case 'mr':
        return 'रोगाचे निदान होत आहे...';
      case 'pa':
        return 'ਰੋਗ ਦੀ ਜਾਂਚ ਹੋ ਰਹੀ ਹੈ...';
      case 'hi':
        return 'रोग की जांच हो रही है...';
      case 'en':
      default:
        return 'Diagnosing pathology...';
    }
  }

  String _getLocalizedAlignCameraText(String lang) {
    switch (lang) {
      case 'mr':
        return 'कॅमेऱ्याच्या चौकटीत पिकाचे पान किंवा रोप ठेवा';
      case 'pa':
        return 'ਕੈਮਰੇ ਦੇ ਫਰੇਮ ਵਿੱਚ ਪੱਤਾ ਜਾਂ ਪੌਦਾ ਰੱਖੋ';
      case 'hi':
        return 'कैमरे के फ्रेम में पत्ते या पौधे को रखें';
      case 'en':
      default:
        return 'Align crop leaf or plant inside frame';
    }
  }

  String _getLocalizedCapturedPhotoText(String lang) {
    switch (lang) {
      case 'mr':
        return 'घेतलेला फोटो';
      case 'pa':
        return 'ਖਿੱਚੀ ਗਈ ਫੋਟੋ';
      case 'hi':
        return 'कैप्चर किया गया फोटो';
      case 'en':
      default:
        return 'Captured Photo';
    }
  }

  String _getLocalizedSampleTitle(int idx, String lang) {
    switch (idx) {
      case 0:
        switch (lang) {
          case 'mr':
            return 'गव्हाचे पान (पिवळा तांबेरा / रतुआ)';
          case 'pa':
            return 'ਕਣਕ ਦਾ ਪੱਤਾ (ਪੀਲੀ ਕੁੰਗੀ / ਯੈਲੋ ਰਸਟ)';
          case 'hi':
            return 'गेहूं का पत्ता (पीला रतुआ / स्ट्राइप रस्ट)';
          case 'en':
          default:
            return 'Wheat Foliage (Stripe Rust / Yellow Rust)';
        }
      case 1:
        switch (lang) {
          case 'mr':
            return 'कापूस पीक (पांढरी माशी)';
          case 'pa':
            return 'ਨਰਮਾ ਖੇਤ (ਚਿੱਟੀ ਮੱਖੀ)';
          case 'hi':
            return 'कपास का खेत (सफेद मक्खी)';
          case 'en':
          default:
            return 'Cotton Field (Whitefly / Boll Stage)';
        }
      case 2:
        switch (lang) {
          case 'mr':
            return 'टोमॅटो करपा रोग';
          case 'pa':
            return 'ਟਮਾਟਰ ਅਗੇਤਾ ਝੁਲਸ ਰੋਗ';
          case 'hi':
            return 'टमाटर अगेती झुलसा';
          case 'en':
          default:
            return 'Tomato Early Blight Lesions';
        }
      case 3:
      default:
        switch (lang) {
          case 'mr':
            return 'मिरची पान चुरडा व थ्रिप्स';
          case 'pa':
            return 'ਮਿਰਚ ਪੱਤਾ ਮਰੋੜ ਤੇ ਥ੍ਰਿਪਸ';
          case 'hi':
            return 'मिर्च पर्ण कुंचन व थ्रिप्स';
          case 'en':
          default:
            return 'Chilli Leaf Curl & Thrips Infestation';
        }
    }
  }

  String _getLocalizedTrySampleText(String lang) {
    switch (lang) {
      case 'mr':
        return 'नमुना तपासा';
      case 'pa':
        return 'ਨਮੂਨਾ ਵੇਖੋ';
      case 'hi':
        return 'नमूना देखें';
      case 'en':
      default:
        return 'Try Sample';
    }
  }

  String _getLocalizedTakePhotoText(String lang) {
    switch (lang) {
      case 'mr':
        return 'फोटो काढा';
      case 'pa':
        return 'ਫੋਟੋ ਖਿੱਚੋ';
      case 'hi':
        return 'फोटो लें';
      case 'en':
      default:
        return 'Take Photo';
    }
  }

  String _getLocalizedGalleryText(String lang) {
    switch (lang) {
      case 'mr':
        return 'गॅलरी';
      case 'pa':
        return 'ਗੈਲਰੀ';
      case 'hi':
        return 'गैलरी';
      case 'en':
      default:
        return 'Gallery';
    }
  }

  String _getLocalizedGuideText(String lang) {
    switch (lang) {
      case 'mr':
        return '१. \'फोटो काढा\' दाबा किंवा गॅलरीतून पानाचा फोटो निवडा.\n२. कॅमेऱ्याच्या फ्रेममध्ये पिकाचे पान किंवा झाड केंद्रित करा.\n३. प्रमाण AI रोगाचे अचूक निदान करून योग्य औषध सुचवेल.';
      case 'pa':
        return '1. \'ਫੋਟੋ ਖਿੱਚੋ\' ਦਬਾਓ ਜਾਂ ਗੈਲਰੀ ਵਿੱਚੋਂ ਪੱਤੇ ਦੀ ਫੋਟੋ ਚੁਣੋ।\n2. ਕੈਮਰੇ ਦੇ ਫਰੇਮ ਵਿੱਚ ਫਸਲ ਦਾ ਪੱਤਾ ਜਾਂ ਪੌਦਾ ਰੱਖੋ।\n3. ਪ੍ਰਮਾਣ AI ਰੋਗ ਦੀ ਪਛਾਣ ਕਰਕੇ ਤੁਰੰਤ ਸਹੀ ਦਵਾਈ ਦੱਸੇਗਾ।';
      case 'hi':
        return '१. \'फोटो लें\' दबाएं या गैलरी से पत्ते का चित्र चुनें।\n२. कैमरे को फसल के पत्ते या तने पर केंद्रित करें।\n३. प्रमाण AI रोग पहचान कर तुरंत सटीक दवा बताएगा।';
      case 'en':
      default:
        return '1. Tap \'Take Photo\' or choose an image from Gallery.\n2. Align camera on the crop leaf, fruit, or plant canopy.\n3. Pramaan AI will identify the crop, diagnose pathology, and prescribe treatments.';
    }
  }

  String _getLocalizedRecentAnalysesTitle(String lang) {
    switch (lang) {
      case 'mr':
        return 'नुकतीच झालेली तपासणी';
      case 'pa':
        return 'ਹਾਲੀਆ ਜਾਂਚ';
      case 'hi':
        return 'हालिया जांच';
      case 'en':
      default:
        return 'Recent Analyses';
    }
  }

  String _getLocalizedViewAllText(String lang) {
    switch (lang) {
      case 'mr':
        return 'सर्व पहा';
      case 'pa':
        return 'ਸਾਰੇ ਵੇਖੋ';
      case 'hi':
        return 'सभी देखें';
      case 'en':
      default:
        return 'View All';
    }
  }

  String _getLocalizedRecentItemTitle(int idx, String lang) {
    if (idx == 0) {
      switch (lang) {
        case 'mr':
          return 'गहू पान (पिवळा तांबेरा)';
        case 'pa':
          return 'ਕਣਕ ਪੱਤਾ (ਪੀਲੀ ਕੁੰਗੀ)';
        case 'hi':
          return 'गेहूं पत्ता (पीला रतुआ)';
        case 'en':
        default:
          return 'Wheat Foliar (Stripe Rust)';
      }
    } else {
      switch (lang) {
        case 'mr':
          return 'कापूस (पांढरी माशी)';
        case 'pa':
          return 'ਨਰਮਾ (ਚਿੱਟੀ ਮੱਖੀ)';
        case 'hi':
          return 'कपास (सफेद मक्खी)';
        case 'en':
        default:
          return 'Cotton (Whitefly)';
      }
    }
  }

  String _getLocalizedRecentConfidence(int pct, String lang) {
    switch (lang) {
      case 'mr':
        return '$pct% अचूकतेसह ओळखले गेले';
      case 'pa':
        return '$pct% ਭਰੋਸੇਯੋਗਤਾ ਨਾਲ ਪਛਾਣ ਕੀਤੀ';
      case 'hi':
        return '$pct% सटीकता के साथ पहचाना गया';
      case 'en':
      default:
        return 'Detected with $pct% confidence';
    }
  }

  String _getLocalizedDaysAgo(int days, String lang) {
    switch (lang) {
      case 'mr':
        return '$days दिवसांपूर्वी';
      case 'pa':
        return '$days ਦਿਨ ਪਹਿਲਾਂ';
      case 'hi':
        return '$days दिन पहले';
      case 'en':
      default:
        return '$days days ago';
    }
  }

  String _getLocalizedIdentifiedBadge(String lang) {
    switch (lang) {
      case 'mr':
        return 'तपासले';
      case 'pa':
        return 'ਪਛਾਣਿਆ';
      case 'hi':
        return 'जांच पूर्ण';
      case 'en':
      default:
        return 'Identified';
    }
  }

  Widget _buildFarmLandscapeFooter() {
    return Container(
      width: double.infinity,
      height: 70,
      margin: const EdgeInsets.only(top: 8),
      child: CustomPaint(
        painter: _FarmLandscapePainter(),
      ),
    );
  }
}

// Custom Painter for rural farm hill scenery at the bottom of the diagnosis page
class _FarmLandscapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLightGreen = Paint()
      ..color = const Color(0xFFDCFCE7)
      ..style = PaintingStyle.fill;

    final paintMediumGreen = Paint()
      ..color = const Color(0xFFBBF7D0)
      ..style = PaintingStyle.fill;

    final paintDarkTrees = Paint()
      ..color = const Color(0xFF86EFAC)
      ..style = PaintingStyle.fill;

    // Background rolling hill
    final pathBack = Path();
    pathBack.moveTo(0, size.height);
    pathBack.quadraticBezierTo(size.width * 0.25, size.height * 0.45, size.width * 0.6, size.height * 0.65);
    pathBack.quadraticBezierTo(size.width * 0.85, size.height * 0.85, size.width, size.height * 0.5);
    pathBack.lineTo(size.width, size.height);
    pathBack.close();
    canvas.drawPath(pathBack, paintLightGreen);

    // Foreground rolling hill
    final pathFront = Path();
    pathFront.moveTo(0, size.height * 0.7);
    pathFront.quadraticBezierTo(size.width * 0.35, size.height * 0.35, size.width * 0.75, size.height * 0.65);
    pathFront.quadraticBezierTo(size.width * 0.9, size.height * 0.8, size.width, size.height * 0.6);
    pathFront.lineTo(size.width, size.height);
    pathFront.lineTo(0, size.height);
    pathFront.close();
    canvas.drawPath(pathFront, paintMediumGreen);

    // Decorative farm trees / foliage dots
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.52), 9, paintDarkTrees);
    canvas.drawCircle(Offset(size.width * 0.83, size.height * 0.58), 7, paintDarkTrees);
    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.62), 11, paintDarkTrees);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.68), 12, paintDarkTrees);
    canvas.drawCircle(Offset(size.width * 0.14, size.height * 0.74), 8, paintDarkTrees);

    // Cute small farm hut shape
    final housePaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.fill;
    final roofPaint = Paint()
      ..color = const Color(0xFF047857)
      ..style = PaintingStyle.fill;

    final hutX = size.width * 0.70;
    final hutY = size.height * 0.58;
    canvas.drawRect(Rect.fromLTWH(hutX, hutY, 14, 10), housePaint);
    final roofPath = Path();
    roofPath.moveTo(hutX - 2, hutY);
    roofPath.lineTo(hutX + 7, hutY - 6);
    roofPath.lineTo(hutX + 16, hutY);
    roofPath.close();
    canvas.drawPath(roofPath, roofPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
