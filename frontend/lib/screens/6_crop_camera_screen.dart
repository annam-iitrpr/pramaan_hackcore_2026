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
import 'agri_store_screen.dart';

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
      "title": "Wheat Foliage (Yellow Rust / Stripe Rust)",
      "url":
          "https://images.unsplash.com/photo-1500937386664-56d1dfef3854?w=800&auto=format&fit=crop&q=80",
      "crop": "Wheat",
    },
    {
      "title": "Rice / Paddy (Sheath Blight & Stem Pathology)",
      "url":
          "https://images.unsplash.com/photo-1536657464919-892534f60d6e?w=800&auto=format&fit=crop&q=80",
      "crop": "Rice",
    },
    {
      "title": "Cotton Field (Whitefly / Bollworm Infestation)",
      "url":
          "https://images.unsplash.com/photo-1530836369250-ef72a3f5cda8?w=800&auto=format&fit=crop&q=80",
      "crop": "Cotton",
    },
    {
      "title": "Tomato Early Blight Lesions",
      "url":
          "https://images.unsplash.com/photo-1592841200221-a6898f307baa?w=800&auto=format&fit=crop&q=80",
      "crop": "Tomato",
    },
    {
      "title": "Chilli Leaf Curl & Thrips Infestation",
      "url":
          "https://images.unsplash.com/photo-1588252303782-cb80119abd6d?w=800&auto=format&fit=crop&q=80",
      "crop": "Chilli",
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

    final detectedCrop = _diagnosisResult!['crop_detected'] ?? _selectedCrop;
    final disease = _diagnosisResult!['disease_detected'] ?? 'Crop Foliar Scan';
    final severity = _diagnosisResult!['severity_level'] ?? 'Normal';
    final chemical =
        _diagnosisResult!['recommended_active_ingredient'] ??
        'Standard Foliar Treatment';

    await evProv.addEvidence(
      title: "Crop Scan: $detectedCrop • $disease",
      description:
          "$disease identified on $detectedCrop ($severity severity). Recommendation: $chemical.",
      evidenceType: 'CROP_IMAGE',
      mediaUrl: _capturedFile?.path ?? _presetSamples[_presetIndex]['url'],
      productName: chemical,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "$detectedCrop diagnostic evidence sealed & saved to Farm Journal!",
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          duration: const Duration(seconds: 3),
        ),
      );
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
    final crop = res['crop_detected'] ?? _selectedCrop;
    final disease = res['disease_detected'] ?? 'Crop Foliar Scan';
    final chem = _getStep1Chemical(res, lang);
    final mix = _getStep1Mix(res, lang);
    final method = _getStep2Method(res, lang);
    final timing = _getStep3Timing(res, lang);

    String speech = '';
    switch (lang) {
      case 'mr':
        speech = 'पीक सल्ला: पिकाचे नाव $crop. रोग किंवा कीड $disease. काय करावे? पहिले: $chem $mix. दुसरे: $method. तिसरे: $timing.';
        break;
      case 'pa':
        speech = 'ਫਸਲ ਸਲਾਹ: ਫਸਲ $crop. ਰੋਗ ਜਾਂ ਕੀੜਾ $disease. ਕੀ ਕਰਨਾ ਹੈ? ਪਹਿਲਾ: $chem $mix. ਦੂਜਾ: $method. ਤੀਜਾ: $timing.';
        break;
      case 'hi':
        speech = 'फसल सलाह: फसल $crop. रोग या कीट $disease. क्या करें? पहला: $chem $mix. दूसरा: $method. तीसरा: $timing.';
        break;
      case 'en':
      default:
        speech = 'Crop Advisory: Crop $crop. Detected condition $disease. What to do? Step 1: $chem $mix. Step 2: $method. Step 3: $timing.';
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

  // ============================================================
  // ADVISORY DATA EXTRACTION HELPERS
  // ============================================================

  String _getDiseaseCategory(Map<String, dynamic> res, String lang) {
    final rawCat = res['disease_category']?.toString();
    if (rawCat != null && rawCat.isNotEmpty) {
      if (lang == 'hi') {
        if (rawCat.toLowerCase().contains('fungal')) return 'फफूंद जनित रोग (Fungal disease)';
        if (rawCat.toLowerCase().contains('pest') || rawCat.toLowerCase().contains('insect')) return 'कीट का प्रकोप (Insect pest)';
        if (rawCat.toLowerCase().contains('viral')) return 'विषाणु जनित रोग (Viral disease)';
        if (rawCat.toLowerCase().contains('bacterial')) return 'जीवाणु रोग (Bacterial disease)';
      }
      if (lang == 'mr') {
        if (rawCat.toLowerCase().contains('fungal')) return 'बुरशीजन्य रोग (Fungal disease)';
        if (rawCat.toLowerCase().contains('pest') || rawCat.toLowerCase().contains('insect')) return 'कीड प्रादुर्भाव (Insect pest)';
        if (rawCat.toLowerCase().contains('viral')) return 'विषाणूजन्य रोग (Viral disease)';
        if (rawCat.toLowerCase().contains('bacterial')) return 'जिवाणू रोग (Bacterial disease)';
      }
      return rawCat;
    }

    final disease = (res['disease_detected'] ?? '').toString().toLowerCase();
    if (disease.contains('rust') || disease.contains('blight') || disease.contains('blast') || disease.contains('mildew') || disease.contains('rot')) {
      return lang == 'hi' ? 'फफूंद जनित रोग (Fungal disease)' : (lang == 'mr' ? 'बुरशीजन्य रोग (Fungal disease)' : 'Fungal disease');
    }
    if (disease.contains('curl') || disease.contains('mosaic') || disease.contains('virus')) {
      return lang == 'hi' ? 'विषाणु जनित रोग (Viral disease)' : (lang == 'mr' ? 'विषाणूजन्य रोग (Viral disease)' : 'Viral disease');
    }
    if (disease.contains('whitefly') || disease.contains('thrips') || disease.contains('aphid') || disease.contains('borer') || disease.contains('worm')) {
      return lang == 'hi' ? 'कीट प्रादुर्भाव (Insect pest)' : (lang == 'mr' ? 'कीड प्रादुर्भाव (Insect pest)' : 'Insect pest infestation');
    }
    return lang == 'hi' ? 'पादप रोग (Plant pathology)' : (lang == 'mr' ? 'पीक रोग (Plant pathology)' : 'Plant pathology');
  }

  String _getStep1Chemical(Map<String, dynamic> res, String lang) {
    final chem = res['recommended_active_ingredient']?.toString() ?? '';
    if (chem.isNotEmpty && !chem.contains("No verified")) {
      return chem;
    }
    final disease = (res['disease_detected'] ?? '').toString().toLowerCase();
    if (disease.contains('rust')) {
      return lang == 'hi' ? 'प्रोपिकोनाज़ोल 25% EC (टिल्ट) @ 1 ml प्रति लीटर पानी' : 'Use Propiconazole 1 ml per litre of water';
    }
    if (disease.contains('sheath blight')) {
      return lang == 'hi' ? 'वैलिडामाइसिन 3% L @ 2 ml प्रति लीटर पानी या हेक्साकोनाज़ोल @ 2 ml/L' : 'Use Validamycin 3% L @ 2 ml per litre of water';
    }
    if (disease.contains('blast')) {
      return lang == 'hi' ? 'ट्राइसाइक्लाज़ोल 75% WP @ 0.6 g प्रति लीटर पानी' : 'Use Tricyclazole 75% WP @ 0.6 g per litre of water';
    }
    if (disease.contains('leaf curl') || disease.contains('thrips')) {
      return lang == 'hi' ? 'डायाफेन्थियुरॉन 50% WP (पेगासस) @ 1.5 g प्रति लीटर पानी' : 'Use Diafenthiuron 50% WP @ 1.5 g per litre of water';
    }
    if (disease.contains('whitefly')) {
      return lang == 'hi' ? 'पाइरीप्रॉक्सीफेन 10% EC @ 2 ml प्रति लीटर पानी' : 'Use Pyriproxyfen 10% EC @ 2 ml per litre of water';
    }
    if (disease.contains('blight')) {
      return lang == 'hi' ? 'मैनकोज़ेब 75% WP (इंडोफिल M-45) @ 2.5 g प्रति लीटर पानी' : 'Use Mancozeb 75% WP @ 2.5 g per litre of water';
    }
    return lang == 'hi' ? 'मैनकोज़ेब 75% WP @ 2.5 g प्रति लीटर पानी' : 'Use Mancozeb 75% WP @ 2.5 g per litre of water';
  }

  String _getStep1Mix(Map<String, dynamic> res, String lang) {
    if (lang == 'hi') return 'प्रति एकड़ 200 लीटर पानी में अच्छी तरह घोलें।';
    if (lang == 'mr') return 'प्रति एकर २०० लिटर पाण्यात चांगले मिसळा.';
    if (lang == 'pa') return 'ਪ੍ਰਤੀ ਏਕੜ 200 ਲੀਟਰ ਪਾਣੀ ਵਿੱਚ ਮਿਲਾਓ।';
    return 'Mix in 200 litres of water per acre.';
  }

  String _getStep2Method(Map<String, dynamic> res, String lang) {
    final method = res['application_method']?.toString();
    if (method != null && method.isNotEmpty) return method;
    if (lang == 'hi') return 'पत्तियों के दोनों तरफ (ऊपर और नीचे) अच्छी तरह स्प्रे करें।';
    if (lang == 'mr') return 'पानांच्या दोन्ही बाजूंवर (वर आणि खाली) संपूर्ण फवारणी करा.';
    if (lang == 'pa') return 'ਪੱਤਿਆਂ ਦੇ ਦੋਵੇਂ ਪਾਸੇ ਚੰਗੀ ਤਰ੍ਹਾਂ ਸਪਰੇਅ ਕਰੋ।';
    return 'Spray on the leaves, covering both sides.';
  }

  String _getStep3Timing(Map<String, dynamic> res, String lang) {
    final timing = res['timing_weather']?.toString();
    if (timing != null && timing.isNotEmpty) return timing;
    if (lang == 'hi') return '3 दिन के भीतर करें, सुबह के समय जब हवा शांत और मौसम ठंडा हो।';
    if (lang == 'mr') return '३ दिवसांच्या आत करा, शक्यतो सकाळी हवा शांत आणि थंड असताना.';
    if (lang == 'pa') return '3 ਦਿਨਾਂ ਦੇ ਅੰਦਰ ਕਰੋ, ਤਰਜੀਹੀ ਤੌਰ ਤੇ ਸਵੇਰੇ ਜਦੋਂ ਮੌਸਮ ਠੰਡਾ ਹੋਵੇ।';
    return 'Do it within 3 days, preferably in the morning when the weather is cool.';
  }

  String _getProtectionNote(Map<String, dynamic> res, String lang) {
    if (lang == 'hi') return 'यह बीमारी को नियंत्रित करने और आपकी फसल की सुरक्षा करने में मदद करेगा।';
    if (lang == 'mr') return 'हे रोगावर नियंत्रण ठेवण्यास आणि तुमच्या पिकाचे रक्षण करण्यास मदत करेल.';
    if (lang == 'pa') return 'ਇਹ ਬਿਮਾਰੀ ਨੂੰ ਰੋਕਣ ਅਤੇ ਤੁਹਾਡੀ ਫਸਲ ਦੀ ਰੱਖਿਆ ਕਰਨ ਵਿੱਚ ਮਦਦ ਕਰੇਗਾ।';
    return 'This will help control the disease and protect your crop.';
  }

  Map<String, String> _getStoreProductForDiagnosis(Map<String, dynamic> res, String lang) {
    final disease = (res['disease_detected'] ?? '').toString().toLowerCase();
    final crop = (res['crop_detected'] ?? _selectedCrop).toString().toLowerCase();
    final chem = (res['recommended_active_ingredient'] ?? '').toString().toLowerCase();

    if (disease.contains('rust') || crop.contains('wheat') || chem.contains('propiconazole') || chem.contains('tilt')) {
      return {
        "search": "Tilt",
        "product_name": "Tilt 25% EC (Propiconazole)",
        "brand": "Syngenta India Ltd.",
        "category": "Fungicide",
        "crop": "Wheat",
        "price": "₹540",
        "unit": "250 ml Bottle",
        "badge": lang == 'hi' ? 'QR सत्यापित' : (lang == 'mr' ? 'QR प्रमाणित' : 'QR Verified'),
      };
    }
    if (disease.contains('sheath blight') || disease.contains('blast') || crop.contains('rice') || crop.contains('paddy') || chem.contains('validamycin')) {
      return {
        "search": "Validamycin",
        "product_name": "Validamycin 3% L",
        "brand": "Sumitomo Chemical India",
        "category": "Fungicide",
        "crop": "Rice",
        "price": "₹490",
        "unit": "500 ml Bottle",
        "badge": lang == 'hi' ? 'QR सत्यापित' : (lang == 'mr' ? 'QR प्रमाणित' : 'QR Verified'),
      };
    }
    if (disease.contains('leaf curl') || disease.contains('thrips') || disease.contains('mite') || crop.contains('chilli') || chem.contains('diafenthiuron') || chem.contains('pegasus')) {
      return {
        "search": "Pegasus",
        "product_name": "Pegasus (Diafenthiuron 50% WP)",
        "brand": "Syngenta India Ltd.",
        "category": "Insecticide",
        "crop": "Chilli",
        "price": "₹720",
        "unit": "250 g Pack",
        "badge": lang == 'hi' ? 'QR सत्यापित' : (lang == 'mr' ? 'QR प्रमाणित' : 'QR Verified'),
      };
    }
    if (disease.contains('whitefly') || disease.contains('bollworm') || crop.contains('cotton') || chem.contains('neem') || chem.contains('pyriproxyfen')) {
      return {
        "search": "Bio-Neem",
        "product_name": "Bio-Neem Power 10,000 PPM",
        "brand": "Pramaan Eco Bio-Agri",
        "category": "Organic",
        "crop": "Cotton",
        "price": "₹380",
        "unit": "500 ml Bottle",
        "badge": lang == 'hi' ? '100% जैविक' : (lang == 'mr' ? '१००% सेंद्रिय' : '100% Organic'),
      };
    }
    if (disease.contains('blight') || crop.contains('tomato') || crop.contains('potato') || chem.contains('trichoderma') || chem.contains('mancozeb')) {
      return {
        "search": "Trichoderma",
        "product_name": "Trichoderma Viride Bio-Fungicide",
        "brand": "National Bio-Fertilizers",
        "category": "Organic",
        "crop": "Tomato",
        "price": "₹260",
        "unit": "1 kg Pack",
        "badge": lang == 'hi' ? '100% जैविक' : (lang == 'mr' ? '१००% सेंद्रिय' : '100% Organic'),
      };
    }

    return {
      "search": "Tilt",
      "product_name": "Tilt 25% EC (Propiconazole)",
      "brand": "Syngenta India Ltd.",
      "category": "Fungicide",
      "crop": "Wheat",
      "price": "₹540",
      "unit": "250 ml Bottle",
      "badge": lang == 'hi' ? 'QR सत्यापित' : (lang == 'mr' ? 'QR प्रमाणित' : 'QR Verified'),
    };
  }

  void _navigateToStoreForProduct(Map<String, String> storeProduct) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgriStoreScreen(
          initialSearch: storeProduct['search'],
          initialCategory: storeProduct['category'],
          initialCrop: storeProduct['crop'],
        ),
      ),
    );
  }

  // ============================================================
  // MAIN BUILD DISPATCHER
  // ============================================================

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
          ? _buildDiagnosisResultView(lang)
          : _buildCameraCaptureView(lang),
      bottomNavigationBar: const CustomBottomNav(
        currentIndex: -1,
      ),
    );
  }

  // ============================================================
  // 1. DIAGNOSIS RESULT SCREEN (MATCHES 2ND SCREENSHOT EXACTLY)
  // ============================================================

  Widget _buildDiagnosisResultView(String lang) {
    final res = _diagnosisResult!;
    final cropName = res['crop_detected'] ?? (_selectedCrop == "Auto-Detect" ? "Wheat" : _selectedCrop);
    final diseaseName = res['disease_detected'] ?? 'Yellow Rust';
    final category = _getDiseaseCategory(res, lang);
    final confidencePercent = ((res['confidence'] ?? 0.85) * 100).toInt();

    final step1Chemical = _getStep1Chemical(res, lang);
    final step1Mix = _getStep1Mix(res, lang);
    final step2Method = _getStep2Method(res, lang);
    final step3Timing = _getStep3Timing(res, lang);
    final protectNote = _getProtectionNote(res, lang);
    final storeProduct = _getStoreProductForDiagnosis(res, lang);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------
          // 1. Top Crop Header Card
          // ----------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF2FBF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD1FAE5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Color(0xFF15803D),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTranslations.tr(lang, "crop_label", "Crop"),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      cropName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _diagnosisResult = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppTranslations.tr(lang, "change_crop", "Change Crop"),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ----------------------------------------------------
          // 2. Main White Diagnosis Card
          // ----------------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Disease Name & Match Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diseaseName,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            category,
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
                          const Icon(Icons.eco_rounded, size: 14, color: Color(0xFF15803D)),
                          const SizedBox(width: 4),
                          Text(
                            "$confidencePercent% Match",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Leaf Image Preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: _capturedImageBytes != null
                        ? (kIsWeb
                            ? Image.memory(_capturedImageBytes!, fit: BoxFit.cover)
                            : Image.file(File(_capturedFile!.path), fit: BoxFit.cover))
                        : Image.network(
                            _presetSamples[_presetIndex]['url']!,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, _, _) => Container(
                              color: const Color(0xFFECFDF5),
                              child: const Icon(Icons.eco_rounded, color: Color(0xFF047857), size: 40),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // ------------------------------------------------
                // Listen to Advice Audio Banner
                // ------------------------------------------------
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDCFCE7)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF047857),
                        child: const Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isSpeaking
                                  ? (lang == 'hi' ? 'सलाह सुनाई जा रही है...' : (lang == 'mr' ? 'सल्ला ऐकवला जात आहे...' : 'Playing Advisory...'))
                                  : (lang == 'hi' ? 'सलाह सुनें' : (lang == 'mr' ? 'सल्ला ऐका' : 'Listen to Advice')),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              lang == 'hi' ? 'समाधान सुनने के लिए टैप करें' : (lang == 'mr' ? 'उपाय ऐकण्यासाठी टॅप करा' : 'Tap to hear the solution'),
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
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFDCFCE7),
                          child: Icon(
                            _isSpeaking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                            color: const Color(0xFF047857),
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ------------------------------------------------
                // "What to do?" Action Plan Box
                // ------------------------------------------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAF8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(
                            Icons.eco_rounded,
                            color: Color(0xFF15803D),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            lang == 'hi' ? 'क्या करें?' : (lang == 'mr' ? 'काय करावे?' : (lang == 'pa' ? 'ਕੀ ਕਰਨਾ ਹੈ?' : 'What to do?')),
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Step 1: Chemical & Dosage
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.medication_liquid_rounded,
                              color: Color(0xFF047857),
                              size: 24,
                            ),
                          ),
                          Container(
                            width: 1.5,
                            height: 44,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: const Color(0xFFE2E8F0),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step1Chemical,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  step1Mix,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Recommended Store Input Card with direct Buy Redirection
                      Container(
                        margin: const EdgeInsets.only(left: 6, top: 4, bottom: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF047857),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    lang == 'hi'
                                        ? 'अनुशंसित दवा (दुकान में)'
                                        : (lang == 'mr'
                                            ? 'शिफारस केलेले औषध'
                                            : (lang == 'pa' ? 'ਸਿਫਾਰਸ਼ ਕੀਤੀ ਦਵਾਈ' : 'Recommended Input')),
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF15803D)),
                                      const SizedBox(width: 3),
                                      Text(
                                        storeProduct['badge'] ?? "QR Verified",
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.shopping_bag_rounded, color: Color(0xFF047857), size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        storeProduct['product_name']!,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${storeProduct['brand']} • ${storeProduct['price']} (${storeProduct['unit']})",
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 38,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF047857),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                icon: const Icon(Icons.storefront_rounded, size: 16),
                                label: Text(
                                  lang == 'hi'
                                      ? 'दुकान से खरीदें • ${storeProduct['price']}'
                                      : (lang == 'mr'
                                          ? 'दुकानातून खरेदी करा • ${storeProduct['price']}'
                                          : (lang == 'pa' ? 'ਦੁਕਾਨ ਤੋਂ ਖਰੀਦੋ • ${storeProduct['price']}' : 'Buy from Store • ${storeProduct['price']}')),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () => _navigateToStoreForProduct(storeProduct),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Step 2: Application Method
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.eco_rounded,
                              color: Color(0xFF15803D),
                              size: 22,
                            ),
                          ),
                          Container(
                            width: 1.5,
                            height: 36,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: const Color(0xFFE2E8F0),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                step2Method,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF334155),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Step 3: Timing / Weather Window
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            child: const Icon(
                              Icons.wb_sunny_rounded,
                              color: Color(0xFFD97706),
                              size: 22,
                            ),
                          ),
                          Container(
                            width: 1.5,
                            height: 40,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: const Color(0xFFE2E8F0),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                step3Timing,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF334155),
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Bottom Protection Note Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF15803D),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                protectNote,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF15803D),
                                  height: 1.25,
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

          // ----------------------------------------------------
          // 3. Action Buttons: Buy from Store & Save in Journal
          // ----------------------------------------------------
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToStoreForProduct(storeProduct),
              icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20, color: Colors.white),
              label: Text(
                lang == 'hi'
                    ? 'दुकान में दवा देखें व खरीदें (Buy from Store)'
                    : (lang == 'mr'
                        ? 'दुकानात औषध पहा व खरेदी करा'
                        : (lang == 'pa' ? 'ਦੁਕਾਨ ਵਿੱਚ ਦਵਾਈ ਦੇਖੋ ਤੇ ਖਰੀਦੋ' : 'View & Buy Product from Store')),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _saveEvidence,
              icon: const Icon(Icons.bookmark_add_rounded, size: 20, color: Color(0xFF047857)),
              label: Text(
                lang == 'hi' ? 'खाते में सहेजें (Save in Journal)' : (lang == 'mr' ? 'खात्यात जतन करा' : 'Save in My Journal'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF047857),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF047857), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Retake Photo Option
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _diagnosisResult = null;
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
              label: Text(
                lang == 'hi' ? 'दूसरी फोटो खींचें (Retake)' : (lang == 'mr' ? 'दुसरा फोटो घ्या' : 'Retake / Scan Another'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============================================================
  // 2. CAMERA CAPTURE / SAMPLE SELECTOR VIEW
  // ============================================================

  Widget _buildCameraCaptureView(String lang) {
    final activePreset = _presetSamples[_presetIndex];

    final targetCrops = [
      {"label": "Auto-Detect", "icon": Icons.eco_rounded},
      {"label": "Wheat", "emoji": "🌾"},
      {"label": "Rice", "emoji": "🌾"},
      {"label": "Cotton", "emoji": "🌿"},
      {"label": "Tomato", "emoji": "🍅"},
      {"label": "Chilli", "emoji": "🌶️"},
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
                AppTranslations.tr(lang, "target_crop", "Target Crop:"),
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
                                  tc['label'] as String,
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

                  // Center Focus Frame
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
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF10B981),
                              strokeWidth: 3,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Diagnosing crop pathology...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

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
                              AppTranslations.tr(lang, "align_camera", "Align crop leaf or plant inside frame"),
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
                          ? "Captured Photo"
                          : activePreset['title']!,
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
                    "${AppTranslations.tr(lang, "try_sample", "Try Sample")} >",
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

          // Action Buttons Row (Take Photo, Gallery, Diagnose)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => _takePhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                    label: Text(
                      AppTranslations.tr(lang, "take_photo", "Take Photo"),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
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
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: () => _takePhoto(ImageSource.gallery),
                    icon: const Icon(Icons.image_rounded, size: 18, color: Color(0xFF047857)),
                    label: Text(
                      AppTranslations.tr(lang, "gallery", "Gallery"),
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: IconButton(
                  onPressed: _isAnalyzing ? null : _analyzeCurrentPhoto,
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFF047857),
                    size: 26,
                  ),
                  tooltip: "Analyze Current View",
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Crop Doctor AI Guide Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
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
                  lang == 'hi'
                      ? "1. 'फोटो खींचें' या 'गैलरी' से पौधे/पत्ते की फोटो चुनें।\n2. प्रमाण AI फसल की पहचान कर बीमारी का सटीक निदान और दवा की मात्रा बताएगा।"
                      : (lang == 'mr'
                          ? "1. 'फोटो घ्या' किंवा 'गॅलरी' मधून पिकाच्या पानाचा फोटो निवडा.\n2. प्रमाण AI पिकाचा रोग ओळखून अचूक औषध व मात्रा सुचवेल."
                          : "1. Tap 'Take Photo' or choose an image from Gallery.\n2. Pramaan AI identifies pathology and prescribes clear dosage and timing."),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF1E293B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
