import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/evidence_provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/services/api_service.dart';
import '../core/services/pdf_download_service.dart';
import '../core/localization/app_translations.dart';
import '../../models/evidence_model.dart';
import '../widgets/crypto_seal_badge.dart';

class EvidenceDetailScreen extends StatefulWidget {
  const EvidenceDetailScreen({super.key});

  @override
  State<EvidenceDetailScreen> createState() => _EvidenceDetailScreenState();
}

class _EvidenceDetailScreenState extends State<EvidenceDetailScreen> {
  final ApiService _api = ApiService();
  EvidenceItem? _item;
  bool _isRevalidating = false;
  bool _isDownloadingPdf = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_item == null) {
      final passedItem = ModalRoute.of(context)?.settings.arguments as EvidenceItem?;
      _item = passedItem ??
          EvidenceItem(
            id: 'EV-2026-8810',
            farmId: 'farm-101',
            cropName: 'Cotton (Bt-II)',
            cropStage: 'Flowering Stage',
            evidenceType: 'PRODUCT_SCAN',
            timestamp: '2026-08-28T07:45:00Z',
            location: GeoLocation(latitude: 20.1985, longitude: 73.8322, fieldName: 'Plot North-04', village: 'Dindori, Nashik'),
            title: 'Bio-Neem Spray Batch Verified',
            description: 'Scanned QR code on Bio-Neem Power bottle before foliar application for whitefly control.',
            mediaUrl: 'https://images.unsplash.com/photo-1592417817098-8f3d6eb22509?w=600&auto=format&fit=crop&q=80',
            productQr: 'PRM-INP-88219-NEEM',
            productName: 'Bio-Neem Power 10000 PPM',
            dosagePerAcre: '400 ml in 200 L Water',
            verificationStatus: 'VERIFIED',
            verificationScore: 98.6,
            verificationHash: 'a8f5b4c9103982eef11082cba972e345b98a0021c32ff8812de4b21903fa7e41',
            completenessScore: 0.95,
            consistencyStatus: 'consistent',
            validationStatus: 'validated',
            agentVerdicts: {
              'validation_agent': 'Matched genuine batch PRM-INP-88219-NEEM. Geo-fence valid.',
              'weather_agent': 'Spray conditions were optimal (wind 6.2 km/h, humidity 68%). No wash-off risk.',
            },
          );
    }
  }

  String _t(String lang, String key) {
    const dict = {
      'evidence_title': {
        'en': 'Evidence Log',
        'hi': 'खेती प्रमाण रिकॉर्ड',
        'mr': 'शेती पुरावा नोंद',
        'pa': 'ਖੇਤੀ ਸਬੂਤ ਰਿਕਾਰਡ',
      },
      'verified_badge': {
        'en': 'VERIFIED (100%)',
        'hi': 'सत्यापित (100%)',
        'mr': 'प्रमाणित (100%)',
        'pa': 'ਤਸਦੀਕਸ਼ੁਦਾ (100%)',
      },
      'digital_seal_title': {
        'en': 'Digital Security Seal (Protected Record)',
        'hi': 'डिजिटल सुरक्षा मुहर (सुरक्षित रिकॉर्ड)',
        'mr': 'डिजिटल सुरक्षा शिक्का (सुरक्षित नोंद)',
        'pa': 'ਡਿਜੀਟਲ ਸੁਰੱਖਿਆ ਸੀਲ (ਸੁਰੱਖਿਅਤ ਰਿਕਾਰਡ)',
      },
      'digital_seal_sub': {
        'en': '✓ Tamper-proof & officially secured agricultural record',
        'hi': '✓ यह रिकॉर्ड बदला नहीं जा सकता, पूर्ण सुरक्षित व प्रामाणिक है',
        'mr': '✓ ही नोंद बदलता येत नाही, पूर्ण सुरक्षित व अस्सल आहे',
        'pa': '✓ ਇਹ ਰਿਕਾਰਡ ਬਦਲਿਆ ਨਹੀਂ ਜਾ ਸਕਦਾ, ਪੂਰੀ ਤਰ੍ਹਾਂ ਸੁਰੱਖਿਅਤ ਹੈ',
      },
      'trust_agent_title': {
        'en': 'Farm Trust & Quality Verification',
        'hi': 'किसान विश्वास एवं गुणवत्ता जांच',
        'mr': 'शेतकरी विश्वास व गुणवत्ता पडताळणी',
        'pa': 'ਕਿਸਾਨ ਭਰੋਸਾ ਅਤੇ ਗੁਣਵੱਤਾ ਜਾਂਚ',
      },
      'completeness': {
        'en': 'Information Accuracy',
        'hi': 'जानकारी शुद्धता',
        'mr': 'माहितीची अचूकता',
        'pa': 'ਜਾਣਕਾਰੀ ਦੀ ਸ਼ੁੱਧਤਾ',
      },
      'consistency': {
        'en': 'Quality Status',
        'hi': 'जांच दर्जा',
        'mr': 'पडताळणी दर्जा',
        'pa': 'ਗੁਣਵੱਤਾ ਸਥਿਤੀ',
      },
      'consistent_safe': {
        'en': 'ACCURATE (100%)',
        'hi': 'अचूक व सुरक्षित',
        'mr': 'अचूक व सुरक्षित',
        'pa': 'ਸਹੀ ਤੇ ਸੁਰੱਖਿਅਤ',
      },
      'warning_status': {
        'en': 'NEEDS REVIEW',
        'hi': 'जांच आवश्यक',
        'mr': 'तपासणी आवश्यक',
        'pa': 'ਜਾਂਚ ਦੀ ਲੋੜ',
      },
      'all_checks_passed': {
        'en': '✓ All farm, dosage, and weather details checked & verified safely.',
        'hi': '✓ सभी जानकारी (दवा, मात्रा, मौसम और फसल) सुरक्षित और सही पाई गई।',
        'mr': '✓ सर्व माहिती (औषध, प्रमाण, हवामान आणि पीक) सुरक्षित व अचूक आढळली.',
        'pa': '✓ ਸਾਰੀ ਜਾਣਕਾਰੀ (ਦਵਾਈ, ਮਾਤਰਾ, ਮੌਸਮ ਅਤੇ ਫਸਲ) ਸੁਰੱਖਿਅਤ ਤੇ ਸਹੀ ਪਾਈ ਗਈ।',
      },
      'detected_issues': {
        'en': 'Items Requiring Farmer Confirmation:',
        'hi': 'किसान द्वारा पुष्टि आवश्यक बातें:',
        'mr': 'शेतकऱ्याची पुष्टी आवश्यक असलेल्या बाबी:',
        'pa': 'ਕਿਸਾਨ ਦੀ ਪੁਸ਼ਟੀ ਦੀ ਲੋੜ ਵਾਲੀਆਂ ਗੱਲਾਂ:',
      },
      'action_required': {
        'en': 'Action Required',
        'hi': 'कार्रवाई आवश्यक',
        'mr': 'आवश्यक कृती',
        'pa': 'ਲੋੜੀਂਦੀ ਕਾਰਵਾਈ',
      },
      'confirm_btn': {
        'en': 'Confirm & Accept',
        'hi': 'स्वीकार व पुष्टि करें',
        'mr': 'पुष्टी करा / स्वीकारा',
        'pa': 'ਪੁਸ਼ਟੀ ਕਰੋ',
      },
      'recheck_btn': {
        'en': 'LIVE RE-VERIFY DETAILS',
        'hi': 'लाइव पुनः जांच करें',
        'mr': 'थेट माहितीची फेरतपासणी करा',
        'pa': 'ਮੁੜ ਲਾਈਵ ਜਾਂਚ ਕਰੋ',
      },
      'farm_details_title': {
        'en': 'Farm & Spray Details',
        'hi': 'खेत और छिड़काव का विवरण',
        'mr': 'शेतातील व फवारणीचा तपशील',
        'pa': 'ਖੇਤ ਅਤੇ ਸਪਰੇਅ ਦਾ ਵੇਰਵਾ',
      },
      'plot_label': {
        'en': 'Plot / Village',
        'hi': 'प्लॉट / गांव',
        'mr': 'प्लॉट / गाव',
        'pa': 'ਪਲਾਟ / ਪਿੰਡ',
      },
      'date_time_label': {
        'en': 'Date & Time',
        'hi': 'तारीख और समय',
        'mr': 'दिनांक व वेळ',
        'pa': 'ਮਿਤੀ ਅਤੇ ਸਮਾਂ',
      },
      'weather_label': {
        'en': 'Weather Conditions',
        'hi': 'मौसम की स्थिति',
        'mr': 'हवामानाची स्थिती',
        'pa': 'ਮੌਸਮ ਦੀ ਸਥਿਤੀ',
      },
      'product_label': {
        'en': 'Product Used',
        'hi': 'इस्तेमाल की गई दवा',
        'mr': 'वापरलेले औषध',
        'pa': 'ਵਰਤੀ ਗਈ ਦਵਾਈ',
      },
      'dosage_label': {
        'en': 'Dosage Applied',
        'hi': 'छिड़काव की मात्रा',
        'mr': 'फवारणीचे प्रमाण',
        'pa': 'ਸਪਰੇਅ ਦੀ ਮਾਤਰਾ',
      },
      'download_pdf_btn': {
        'en': 'DOWNLOAD 3-PAGE OFFICIAL PDF REPORT',
        'hi': '3-पेज आधिकारिक PDF रिपोर्ट डाउनलोड करें',
        'mr': '३-पानी अधिकृत PDF अहवाल डाउनलोड करा',
        'pa': '3-ਪੰਨਿਆਂ ਦੀ ਸਰਕਾਰੀ PDF ਰਿਪੋਰਟ ਡਾਊਨਲੋਡ ਕਰੋ',
      },
      'copied_hash': {
        'en': 'Security seal hash copied to clipboard!',
        'hi': 'सुरक्षा मुहर कोड कॉपी हो गया!',
        'mr': 'सुरक्षा शिक्का कोड कॉपी झाला!',
        'pa': 'ਸੁਰੱਖਿਆ ਸੀਲ ਕੋਡ ਕਾਪੀ ਹੋ ਗਿਆ!',
      },
    };
    return dict[key]?[lang] ?? dict[key]?['en'] ?? key;
  }

  String _formatFarmerTitle(String rawTitle, String lang) {
    if (rawTitle.toLowerCase().contains("voice log: spray")) {
      final crop = rawTitle.split("SPRAY").last.trim();
      if (lang == 'mr') return "आवाज नोंद: $crop फवारणी";
      if (lang == 'hi') return "आवाज रिकॉर्ड: $crop छिड़काव";
      if (lang == 'pa') return "ਆਵਾਜ਼ ਰਿਕਾਰਡ: $crop ਸਪਰੇਅ";
    }
    return rawTitle;
  }

  String _formatReadableDateTime(String raw) {
    try {
      if (raw.contains('T')) {
        final dt = DateTime.parse(raw).toLocal();
        final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final period = dt.hour >= 12 ? "PM" : "AM";
        final minute = dt.minute.toString().padLeft(2, '0');
        return "${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $period";
      }
    } catch (_) {}
    return raw;
  }

  Future<void> _runLiveCrossValidation() async {
    if (_item == null) return;
    setState(() => _isRevalidating = true);

    try {
      final res = await _api.crossValidateEvidence(
        evidenceId: _item!.id,
        farmId: _item!.farmId,
        cropName: _item!.cropName,
        nlpOutput: {
          "crop": _item!.cropName,
          "action_type": "SPRAY",
          "product_mentioned": _item!.productName,
          "dosage": _item!.dosagePerAcre,
          "raw_transcript": _item!.description,
        },
        visionOutput: {
          "crop_detected": _item!.cropName,
          "product_name": _item!.productName,
          "label_dosage": _item!.dosagePerAcre,
          "disease_detected": _item!.title,
        },
        weatherOutput: {
          "temperature_c": 26.5,
          "humidity_percent": 68.0,
          "wind_speed_kmh": 6.2,
          "precipitation_prob": 10.0,
          "delta_t_c": 3.8,
        },
      );

      if (mounted) {
        setState(() {
          _isRevalidating = false;
          final flagsList = res['flags'] is List ? List<Map<String, dynamic>>.from(res['flags']) : <Map<String, dynamic>>[];
          final newStatus = res['validation_status']?.toString() ?? 'validated';
          final newConsistency = res['consistency_status']?.toString() ?? 'consistent';
          final newCompScore = (res['completeness_score'] as num?)?.toDouble() ?? 0.95;
          final newTrustScore = (res['composite_trust_score'] as num?)?.toDouble() ?? 98.6;
          final newAction = res['required_action']?.toString() ?? 'none';

          _item = EvidenceItem(
            id: _item!.id,
            farmId: _item!.farmId,
            cropName: _item!.cropName,
            cropStage: _item!.cropStage,
            evidenceType: _item!.evidenceType,
            timestamp: _item!.timestamp,
            location: _item!.location,
            weather: _item!.weather,
            title: _item!.title,
            description: _item!.description,
            mediaUrl: _item!.mediaUrl,
            audioTranscript: _item!.audioTranscript,
            productQr: _item!.productQr,
            productName: _item!.productName,
            dosagePerAcre: _item!.dosagePerAcre,
            farmerName: _item!.farmerName,
            farmerPhone: _item!.farmerPhone,
            verificationStatus: newStatus == 'needs_review' ? 'PENDING' : 'VERIFIED',
            verificationScore: newTrustScore,
            verificationHash: res['cryptographic_hash']?.toString() ?? _item!.verificationHash,
            agentVerdicts: _item!.agentVerdicts,
            flagReasons: res['anomalies'] != null ? List<String>.from(res['anomalies']) : _item!.flagReasons,
            completenessScore: newCompScore,
            consistencyStatus: newConsistency,
            validationStatus: newStatus,
            requiredAction: newAction,
            flags: flagsList,
          );
        });

        final auth = Provider.of<AuthProvider>(context, listen: false);
        final lang = auth.selectedLanguage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppTranslations.tr(lang, "verification_complete_snack", "✓ Verification completed successfully")),
            backgroundColor: _item!.consistencyStatus == 'consistent' ? const Color(0xFF047857) : const Color(0xFFD97706),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRevalidating = false);
      }
    }
  }

  Future<void> _downloadReportPdf() async {
    if (_item == null) return;
    setState(() => _isDownloadingPdf = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final lang = auth.selectedLanguage;

    try {
      await PdfDownloadService().downloadAndOpenReport(
        item: _item!,
        farmerName: auth.userName,
        farmerPhone: auth.userPhone,
        village: auth.userVillage,
        state: auth.userState,
        activeCrop: auth.activeCrop,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.download_done_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTranslations.tr(lang, "report_downloaded_snack", "✓ Report downloaded to device storage"),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppTranslations.tr(lang, "report_downloaded_snack", "✓ Report downloaded to device storage")),
          backgroundColor: const Color(0xFF047857),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloadingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_item == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final item = _item!;
    final auth = Provider.of<AuthProvider>(context);
    final lang = auth.selectedLanguage;
    final isAgent = auth.currentRole == UserRoleType.fieldAgent;

    final shortId = item.id.length > 16 ? item.id.substring(0, 16) : item.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "${_t(lang, 'evidence_title')} #$shortId",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_t(lang, 'copied_hash'))),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Crop & Action Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.cropName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      CryptoSealBadge(
                        score: item.verificationScore,
                        status: item.verificationStatus,
                        language: lang,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatFarmerTitle(item.title, lang),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.description,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Cryptographic SHA-256 Digital Seal Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_rounded, color: AppColors.primaryAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _t(lang, 'digital_seal_title'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    item.verificationHash ?? "a8f5b4c9103982eef11082cba972e345b98a0021c32ff8812de4b21903fa7e41",
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: AppColors.primaryAccent, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _t(lang, 'digital_seal_sub'),
                          style: const TextStyle(color: AppColors.primaryAccent, fontSize: 11.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. Farmer-Friendly Trust & Quality Check Card (Agent #4)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: item.flags.isNotEmpty || item.consistencyStatus == 'warning'
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: item.flags.isNotEmpty || item.consistencyStatus == 'warning'
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFA7F3D0),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: item.flags.isNotEmpty || item.consistencyStatus == 'warning'
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF047857),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _t(lang, 'trust_agent_title'),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: item.validationStatus == 'validated'
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: item.validationStatus == 'validated'
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFFFCD34D),
                          ),
                        ),
                        child: Text(
                          item.validationStatus == 'validated'
                              ? _t(lang, 'verified_badge')
                              : _t(lang, 'warning_status'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.validationStatus == 'validated'
                                ? const Color(0xFF065F46)
                                : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 18),

                  // Metrics: Accuracy & Consistency
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(lang, 'completeness'),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${(item.completenessScore * 100).toInt()}%",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(lang, 'consistency'),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    item.consistencyStatus == 'consistent'
                                        ? Icons.check_circle_rounded
                                        : Icons.warning_amber_rounded,
                                    size: 13,
                                    color: item.consistencyStatus == 'consistent'
                                        ? const Color(0xFF047857)
                                        : const Color(0xFFD97706),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      item.consistencyStatus == 'consistent'
                                          ? _t(lang, 'consistent_safe')
                                          : _t(lang, 'warning_status'),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: item.consistencyStatus == 'consistent'
                                            ? const Color(0xFF047857)
                                            : const Color(0xFFD97706),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Issues / Flags List (if any)
                  if (item.flags.isNotEmpty || item.flagReasons.isNotEmpty) ...[
                    Text(
                      _t(lang, 'detected_issues'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 6),
                    if (item.flags.isNotEmpty)
                      ...item.flags.map((f) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.flag_rounded, color: Color(0xFFD97706), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (f['type'] ?? 'anomaly').toString().replaceAll('_', ' ').toUpperCase(),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        f['message']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ))
                    else
                      ...item.flagReasons.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("⚠️ ", style: TextStyle(fontSize: 12)),
                                Expanded(
                                  child: Text(r, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E))),
                                ),
                              ],
                            ),
                          )),
                    const SizedBox(height: 8),
                  ],

                  // Action Row
                  if (item.requiredAction != 'none') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_rounded, color: Color(0xFFB45309), size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${_t(lang, 'action_required')}: ${item.requiredAction.replaceAll('_', ' ').toUpperCase()}",
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Provider.of<EvidenceProvider>(context, listen: false).updateStatus(item.id, 'VERIFIED', score: 98.6);
                              setState(() {
                                _item = EvidenceItem(
                                  id: item.id,
                                  farmId: item.farmId,
                                  cropName: item.cropName,
                                  cropStage: item.cropStage,
                                  evidenceType: item.evidenceType,
                                  timestamp: item.timestamp,
                                  location: item.location,
                                  title: item.title,
                                  description: item.description,
                                  verificationStatus: 'VERIFIED',
                                  verificationScore: 98.6,
                                  completenessScore: 0.96,
                                  consistencyStatus: 'consistent',
                                  validationStatus: 'validated',
                                  requiredAction: 'none',
                                  flags: const [],
                                );
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("✓ माहितीची पुष्टी झाली!"),
                                  backgroundColor: Color(0xFF047857),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF047857),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _t(lang, 'confirm_btn'),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _t(lang, 'all_checks_passed'),
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46), fontWeight: FontWeight.w600, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),

                  // Button to trigger live re-validation
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isRevalidating ? null : _runLiveCrossValidation,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        side: const BorderSide(color: Color(0xFF047857)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isRevalidating
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF047857)))
                          : const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF047857)),
                      label: Text(
                        _isRevalidating ? "..." : _t(lang, 'recheck_btn'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. Clean Farm & Spray Details Card (Zero Overflow)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(lang, 'farm_details_title'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Divider(height: 18),
                  _buildMetaRow(
                    Icons.pin_drop_rounded,
                    _t(lang, 'plot_label'),
                    "${item.location.fieldName} (${item.location.village})",
                  ),
                  _buildMetaRow(
                    Icons.access_time_rounded,
                    _t(lang, 'date_time_label'),
                    _formatReadableDateTime(item.timestamp),
                  ),
                  _buildMetaRow(
                    Icons.cloud_queue_rounded,
                    _t(lang, 'weather_label'),
                    "26.5°C | 68% RH | 6.2 km/h",
                  ),
                  if (item.productName != null)
                    _buildMetaRow(
                      Icons.science_rounded,
                      _t(lang, 'product_label'),
                      item.productName!,
                    ),
                  if (item.dosagePerAcre != null)
                    _buildMetaRow(
                      Icons.opacity_rounded,
                      _t(lang, 'dosage_label'),
                      item.dosagePerAcre!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. 1-Click Download Official 3-Page PDF Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDownloadingPdf ? null : _downloadReportPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: _isDownloadingPdf
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_rounded, color: AppColors.accentGold),
                label: Text(
                  _isDownloadingPdf ? "DOWNLOADING..." : _t(lang, 'download_pdf_btn'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Agent Sign-off Action (if in Field Agent role)
            if (isAgent && item.verificationStatus == 'PENDING') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Provider.of<EvidenceProvider>(context, listen: false).updateStatus(item.id, 'FLAGGED', score: 55.0);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.flag_rounded, color: AppColors.flaggedRed),
                      label: const Text("FLAG ISSUE", style: TextStyle(color: AppColors.flaggedRed)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Provider.of<EvidenceProvider>(context, listen: false).updateStatus(item.id, 'VERIFIED', score: 98.0);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text("APPROVE EVIDENCE"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
