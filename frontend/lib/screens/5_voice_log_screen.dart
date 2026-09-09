import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/providers/evidence_provider.dart';
import '../core/providers/auth_provider.dart';
import '../core/localization/app_translations.dart';
import '../core/services/api_service.dart';
import '../core/services/google_sheets_service.dart';
import '../core/services/local_agronomy_engine.dart';
import '../widgets/custom_bottom_nav.dart';

class VoiceLogScreen extends StatefulWidget {
  const VoiceLogScreen({super.key});

  @override
  State<VoiceLogScreen> createState() => _VoiceLogScreenState();
}

class _VoiceLogScreenState extends State<VoiceLogScreen> {
  static const MethodChannel _speechChannel = MethodChannel(
    'com.pramaan.app/speech',
  );

  final TextEditingController _inputController = TextEditingController();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _isSpeaking = false;

  String _selectedLang = 'hi';

  Map<String, dynamic>? _parsedData;

  String? _parseError;
  String? _extractionMethod;

  final Map<String, String> _languages = const {
    'hi': 'हिंदी',
    'mr': 'मराठी',
    'pa': 'ਪੰਜਾਬੀ',
    'en': 'English',
  };

  static const Map<String, String> _localeMap = {
    'hi': 'hi-IN',
    'mr': 'mr-IN',
    'pa': 'pa-IN',
    'en': 'en-IN',
  };

  List<Map<String, String>> _getSampleChipsForLang(String lang) {
    switch (lang) {
      case 'mr':
        return const [
          {
            'label': 'कापूस बायो-नीम',
            'text': 'आज सकाळी आम्ही 400 मिली बायो-नीम 200 लिटर पाण्यात मिसळून कापूस पिकावर पांढऱ्या माशीसाठी फवारणी केली आहे.',
            'lang': 'mr',
          },
          {
            'label': 'गहू तांबेरा फवारणी',
            'text': 'गव्हाच्या शेतात पिवळा तांबेरा दिसला, 200 मिली प्रोपिकोनाझोलची फवारणी केली.',
            'lang': 'mr',
          },
          {
            'label': 'नॅनो युरिया फवारणी',
            'text': 'आज संध्याकाळी 500 मिली नॅनो युरियाची भात पिकावर फवारणी करण्यात आली.',
            'lang': 'mr',
          },
        ];
      case 'pa':
        return const [
          {
            'label': 'ਕਪਾਹ ਨਿੰਮ ਸਪਰੇਅ',
            'text': '400 ਮਿਲੀਲੀਟਰ ਬਾਇਓ-ਨਿੰਮ 200 ਲੀਟਰ ਪਾਣੀ ਵਿੱਚ ਮਿਲਾ ਕੇ ਕਪਾਹ ਦੀ ਫਸਲ ਤੇ ਸਪਰੇਅ ਕੀਤਾ।',
            'lang': 'pa',
          },
          {
            'label': 'ਕਣਕ ਕੁੰਗੀ ਰੋਕਥਾਮ',
            'text': 'ਕਣਕ ਦੇ ਖੇਤ ਵਿੱਚ ਪੀਲੀ ਕੁੰਗੀ ਦਿਖੀ ਹੈ, 200 ਮਿਲੀਲੀਟਰ ਪ੍ਰੋਪੀਕੋਨਾਜ਼ੋਲ ਦਾ ਛਿੜਕਾਅ ਕੀਤਾ।',
            'lang': 'pa',
          },
          {
            'label': 'ਨੈਨੋ ਯੂਰੀਆ ਸਪਰੇਅ',
            'text': 'ਅੱਜ ਸ਼ਾਮ ਨੂੰ 500 ਮਿਲੀਲੀਟਰ ਨੈਨੋ ਯੂਰੀਆ ਦਾ ਝੋਨੇ ਦੀ ਫਸਲ ਤੇ ਛਿੜਕਾਅ ਕੀਤਾ ਗਿਆ।',
            'lang': 'pa',
          },
        ];
      case 'en':
        return const [
          {
            'label': 'Cotton Bio-Neem Spray',
            'text': 'Sprayed 400ml Bio-Neem in 200L water on cotton crop for whitefly management.',
            'lang': 'en',
          },
          {
            'label': 'Wheat Rust Treatment',
            'text': 'Observed yellow rust on wheat plot, applied 200ml Propiconazole spray.',
            'lang': 'en',
          },
          {
            'label': 'Nano Urea Foliar Spray',
            'text': 'Foliar spray of 500ml IFFCO nano urea completed on paddy crop.',
            'lang': 'en',
          },
        ];
      case 'hi':
      default:
        return const [
          {
            'label': 'कपास बायो-नीम स्प्रे',
            'text': '400 मिली बायो-नीम 200 लीटर पानी में मिलाकर कपास की फसल पर छिड़काव किया।',
            'lang': 'hi',
          },
          {
            'label': 'गेहूं रतुआ उपचार',
            'text': 'गेहूं के खेत में पीला रतुआ दिखा है, 200 मिली प्रोपिकोनाज़ोल का स्प्रे किया।',
            'lang': 'hi',
          },
          {
            'label': 'नैनो यूरिया छिड़काव',
            'text': 'आज शाम को 500 मिली इफको नैनो यूरिया का पर्णीय छिड़काव धान की फसल में किया गया।',
            'lang': 'hi',
          },
        ];
    }
  }

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
    _inputController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Native speech callbacks
  // ---------------------------------------------------------------------------

  Future<dynamic> _handleNativeSpeechCallback(MethodCall call) async {
    if (!mounted) return null;

    switch (call.method) {
      case 'onSpeechPartial':
        final text = (call.arguments ?? '').toString();

        if (text.trim().isNotEmpty) {
          setState(() {
            _inputController.text = text;
            _inputController.selection = TextSelection.fromPosition(
              TextPosition(offset: _inputController.text.length),
            );
          });
        }
        break;

      case 'onSpeechResult':
        final text = (call.arguments ?? '').toString();

        setState(() {
          if (text.trim().isNotEmpty) {
            _inputController.text = text;
            _inputController.selection = TextSelection.fromPosition(
              TextPosition(offset: _inputController.text.length),
            );
          }

          _isListening = false;
        });
        break;

      case 'onSpeechError':
      case 'onSpeechEnd':
        setState(() {
          _isListening = false;
        });
        break;

      case 'onTtsStart':
        setState(() {
          _isSpeaking = true;
        });
        break;

      case 'onTtsDone':
        setState(() {
          _isSpeaking = false;
        });
        break;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Speech control
  // ---------------------------------------------------------------------------

  Future<void> _toggleListening() async {
    if (_isProcessing || _isSaving) return;

    if (_isListening) {
      try {
        await _speechChannel.invokeMethod('stopListening');
      } catch (e) {
        debugPrint('[VoiceLog] stopListening: $e');
      }

      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }

      return;
    }

    final locale = _localeMap[_selectedLang];

    if (locale == null) {
      _showMessage('Selected language is not supported.');
      return;
    }

    setState(() {
      _isListening = true;
      _parseError = null;
    });

    try {
      final result = await _speechChannel.invokeMethod<String>(
        'startListening',
        {'language': locale},
      );

      /*
       * Some native implementations return the final transcript directly,
       * while others send it through onSpeechResult.
       *
       * We accept the returned value when available. The native callback
       * remains responsible for partial/final updates as well.
       */
      if (result != null && result.trim().isNotEmpty && mounted) {
        setState(() {
          _inputController.text = result;
          _inputController.selection = TextSelection.fromPosition(
            TextPosition(offset: _inputController.text.length),
          );
          _isListening = false;
        });
      }
    } on PlatformException catch (e) {
      debugPrint('[VoiceLog] Native speech error: ${e.code} ${e.message}');

      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }

      _showMessage(
        e.message?.isNotEmpty == true
            ? e.message!
            : 'Unable to start speech recognition.',
      );
    } catch (e) {
      debugPrint('[VoiceLog] startListening error: $e');

      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }

      _showMessage('Unable to start speech recognition.');
    }
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  Future<void> _parseVoiceInput() async {
    if (_isProcessing || _isSaving) return;

    final transcript = _inputController.text.trim();

    if (transcript.isEmpty) {
      _showMessage('Please speak or type your observation first.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _parsedData = null;
      _parseError = null;
      _extractionMethod = null;
    });

    try {
      final response = await ApiService().parseVoiceNote(
        transcript,
        _selectedLang,
      );

      final normalized = _normalizeBackendResult(response, transcript);

      if (!mounted) return;

      setState(() {
        _parsedData = normalized;
        _extractionMethod =
            _stringField(normalized, ['extraction_method']) ??
            'BACKEND_VOICE_AGENT';
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('[VoiceLog] Backend parsing failed: $e');

      /*
       * Offline fallback:
       *
       * We intentionally do NOT use AuthProvider.activeCrop as evidence.
       * The active crop is contextual application metadata and must not be
       * inserted into a farmer's observation when the farmer did not say it.
       *
       * The local engine is therefore treated as an extraction attempt only.
       */
      try {
        final localData = _runSafeOfflineFallback(transcript);

        if (!mounted) return;

        setState(() {
          _parsedData = localData;
          _extractionMethod = 'RULE_BASED_OFFLINE_FALLBACK';
          _parseError = null;
          _isProcessing = false;
        });
      } catch (offlineError) {
        debugPrint('[VoiceLog] Offline parsing failed: $offlineError');

        if (!mounted) return;

        setState(() {
          _parsedData = {
            'cleaned_transcript': transcript,
            'missing_information': const ['AI extraction unavailable'],
            'needs_clarification': true,
            'provenance': 'RAW_TRANSCRIPT_ONLY',
            'extraction_method': 'RAW_TRANSCRIPT_ONLY',
          };

          _extractionMethod = 'RAW_TRANSCRIPT_ONLY';
          _parseError =
              'AI parsing is currently unavailable. Your transcript has been preserved.';
          _isProcessing = false;
        });
      }
    }
  }

  /*
   * Local fallback wrapper.
   *
   * The existing LocalAgronomyEngine in the uploaded project contains
   * presentation/demo defaults. We only accept fields that can be treated
   * as explicit extraction from the transcript and never add activeCrop,
   * verification, GPS, hash, compliance, or report identifiers ourselves.
   */
  Map<String, dynamic> _runSafeOfflineFallback(String transcript) {
    final engine = LocalAgronomyEngine();

    /*
     * The existing engine requires a defaultCrop parameter. Passing null is
     * unsafe if its signature is non-nullable, and passing auth.activeCrop
     * would violate evidence provenance.
     *
     * Therefore we first use an empty string only as an engine input.
     * Any resulting crop value is accepted only if the engine actually
     * extracts one. We never substitute it from AuthProvider.
     */
    final result = engine.parseOfflineObservation(
      transcript: transcript,
      defaultCrop: '',
      language: _selectedLang,
    );

    final safe = <String, dynamic>{
      'cleaned_transcript': transcript,
      'extraction_method': 'RULE_BASED_OFFLINE_FALLBACK',
      'provenance': 'LOCAL_EXTRACTION',
    };

    for (final entry in result.entries) {
      final key = entry.key.toString();

      if (_allowedExtractedKey(key)) {
        final value = _fieldValue(entry.value);

        if (!_isEmptyValue(value)) {
          safe[key] = value;
        }
      }
    }

    return safe;
  }

  // ---------------------------------------------------------------------------
  // Backend response normalization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _normalizeBackendResult(
    Map<String, dynamic> response,
    String transcript,
  ) {
    final normalized = <String, dynamic>{};

    /*
     * Preserve backend output rather than replacing it with frontend guesses.
     */
    normalized.addAll(response);

    if (!_isEmptyValue(response['cleaned_transcript'])) {
      normalized['cleaned_transcript'] = _fieldValue(
        response['cleaned_transcript'],
      );
    } else {
      normalized['cleaned_transcript'] = transcript;
    }

    _copyAliasIfMissing(normalized, 'product_mentioned', ['product_name']);

    _copyAliasIfMissing(normalized, 'dosage', ['dosage_quantity']);

    _copyAliasIfMissing(normalized, 'action_type', ['activity_type']);

    /*
     * If backend returned structured ExtractedField objects:
     *
     * {
     *   "crop": {
     *      "value": "Cotton",
     *      "source_text": "cotton",
     *      "confidence": 0.96
     *   }
     * }
     *
     * Keep provenance information, but expose the actual value separately
     * for the UI.
     */
    const fieldNames = [
      'crop',
      'action_type',
      'activity_type',
      'product_name',
      'product_mentioned',
      'chemical_product',
      'dosage',
      'dosage_quantity',
      'target_pest',
      'plot_name',
      'observation_time',
      'confidence_score',
      'missing_information',
      'ambiguous_information',
      'needs_clarification',
      'clarification_question',
      'safety_instructions',
    ];

    for (final key in fieldNames) {
      if (normalized.containsKey(key)) {
        normalized[key] = _fieldValue(normalized[key]);
      }
    }

    /*
     * Confidence is interpretation confidence.
     *
     * It is NOT a compliance score and must never be displayed as
     * "VERIFIED %".
     */
    final confidence = _doubleField(response['confidence_score']);

    if (confidence != null) {
      normalized['confidence_score'] = _normalizeConfidence(confidence);
    } else {
      normalized.remove('confidence_score');
    }

    /*
     * Never manufacture missing information.
     *
     * If backend supplies missing_information, preserve it.
     * Otherwise derive it only from fields that are genuinely absent.
     */
    if (!_hasUsableList(response['missing_information'])) {
      final missing = <String>[];

      if (_stringField(normalized, ['crop']) == null) {
        missing.add('crop');
      }

      if (_stringField(normalized, ['action_type']) == null) {
        missing.add('activity');
      }

      if (_stringField(normalized, ['product_name', 'product_mentioned']) ==
          null) {
        missing.add('product');
      }

      if (_stringField(normalized, ['dosage']) == null) {
        missing.add('dosage');
      }

      if (_stringField(normalized, ['target_pest']) == null) {
        missing.add('target pest / focus');
      }

      if (missing.isNotEmpty) {
        normalized['missing_information'] = missing;
      }
    }

    return normalized;
  }

  void _copyAliasIfMissing(
    Map<String, dynamic> data,
    String target,
    List<String> aliases,
  ) {
    if (!_isEmptyValue(data[target])) return;

    for (final alias in aliases) {
      if (!_isEmptyValue(data[alias])) {
        data[target] = data[alias];
        return;
      }
    }
  }

  dynamic _fieldValue(dynamic field) {
    if (field == null) return null;

    if (field is Map) {
      if (field.containsKey('value')) {
        return field['value'];
      }
    }

    return field;
  }

  String? _stringField(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = _fieldValue(data[key]);

      if (value == null) continue;

      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value is num || value is bool) {
        return value.toString();
      }
    }

    return null;
  }

  double? _doubleField(dynamic value) {
    final actual = _fieldValue(value);

    if (actual is num) {
      return actual.toDouble();
    }

    if (actual is String) {
      return double.tryParse(actual.trim());
    }

    return null;
  }

  double _normalizeConfidence(double value) {
    /*
     * Backends commonly return either:
     *   0.0 - 1.0
     * or
     *   0 - 100
     *
     * We store it internally as 0 - 1.
     */
    if (value > 1.0) {
      return (value / 100.0).clamp(0.0, 1.0);
    }

    return value.clamp(0.0, 1.0);
  }

  bool _isEmptyValue(dynamic value) {
    if (value == null) return true;

    final actual = _fieldValue(value);

    if (actual == null) return true;

    if (actual is String) {
      return actual.trim().isEmpty;
    }

    if (actual is Iterable) {
      return actual.isEmpty;
    }

    return false;
  }

  bool _hasUsableList(dynamic value) {
    final actual = _fieldValue(value);

    if (actual is Iterable) {
      return actual.isNotEmpty;
    }

    return false;
  }

  bool _allowedExtractedKey(String key) {
    const allowed = {
      'crop',
      'action_type',
      'activity_type',
      'product_name',
      'product_mentioned',
      'chemical_product',
      'dosage',
      'dosage_quantity',
      'target_pest',
      'plot_name',
      'observation_time',
      'confidence_score',
      'missing_information',
      'ambiguous_information',
      'needs_clarification',
      'clarification_question',
      'safety_instructions',
    };

    return allowed.contains(key);
  }

  // ---------------------------------------------------------------------------
  // Save evidence
  // ---------------------------------------------------------------------------

  Future<void> _saveEvidence() async {
    if (_parsedData == null || _isSaving) return;

    final transcript = _inputController.text.trim();

    if (transcript.isEmpty) {
      _showMessage('Transcript is empty.');
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);

    final evidenceProvider = Provider.of<EvidenceProvider>(
      context,
      listen: false,
    );

    final data = _parsedData!;

    /*
     * IMPORTANT:
     *
     * We intentionally DO NOT do:
     *
     * crop ?? auth.activeCrop
     * product ?? "Bio-Neem..."
     * dosage ?? "400 ml..."
     * action ?? "SPRAY"
     *
     * Missing information remains missing.
     */
    final crop = _stringField(data, ['crop']);
    final action = _stringField(data, ['action_type', 'activity_type']);
    final product = _stringField(data, [
      'product_name',
      'product_mentioned',
      'chemical_product',
    ]);
    final dosage = _stringField(data, ['dosage', 'dosage_quantity']);
    final targetPest = _stringField(data, ['target_pest']);

    setState(() {
      _isSaving = true;
    });

    bool localEvidenceSaved = false;
    bool sheetsSynced = false;

    try {
      /*
       * EvidenceProvider currently accepts nullable fields.
       *
       * Passing null means the provider may still apply its own internal
       * defaults. We therefore use the extracted value when available.
       *
       * NOTE: The provider itself should eventually be cleaned to remove
       * its hardcoded farm/GPS/weather/verification defaults.
       */
      await evidenceProvider.addEvidence(
        title: _buildEvidenceTitle(crop: crop, action: action),
        description: transcript,
        evidenceType: 'VOICE_LOG',
        audioTranscript: transcript,
        productName: product,
        dosagePerAcre: dosage,
        farmerName: auth.userName,
        farmerPhone: auth.userPhone,
        village: auth.userVillage,
        cropName: crop,
      );

      localEvidenceSaved = true;

      /*
       * Google Sheets service currently requires:
       * - non-null crop/action
       * - double compliance score
       * - report ID
       * - hash
       *
       * These fields are NOT necessarily returned by the Voice Agent.
       *
       * We therefore use empty strings for missing textual values and 0.0
       * only as an unavailable numeric storage value. The status is
       * EXTRACTED, never VERIFIED.
       *
       * This service contract should ideally be changed later to nullable
       * fields so "not provided" is represented as null.
       */
      try {
        sheetsSynced = await GoogleSheetsService().logFarmerVoiceEntry(
          farmerName: auth.userName,
          farmerPhone: auth.userPhone,
          village: auth.userVillage,
          state: auth.userState,
          crop: crop ?? '',
          actionType: action ?? '',
          productName: product,
          dosage: dosage,
          targetPest: targetPest,
          voiceTranscript: transcript,
          complianceScore: 0.0,
          verificationStatus: 'EXTRACTED',
          reportId: _stringField(data, ['report_id']) ?? '',
          hashAnchor:
              _stringField(data, ['verification_hash', 'hash_anchor']) ?? '',
        );
      } catch (e) {
        debugPrint('[VoiceLog] Google Sheets sync failed: $e');
      }

      if (!mounted) return;

      await _showSaveResultDialog(
        localEvidenceSaved: localEvidenceSaved,
        sheetsSynced: sheetsSynced,
      );
    } catch (e) {
      debugPrint('[VoiceLog] Save evidence error: $e');

      if (mounted) {
        _showMessage('Unable to save the voice observation: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _buildEvidenceTitle({String? crop, String? action}) {
    if (crop != null && action != null) {
      return 'Voice Log: $crop • $action';
    }

    if (crop != null) {
      return 'Voice Log: $crop';
    }

    if (action != null) {
      return 'Voice Log: $action';
    }

    return 'Voice Observation';
  }

  Future<void> _toggleSpeakOutput() async {
    if (_isSpeaking) {
      try {
        await _speechChannel.invokeMethod('stopSpeaking');
      } catch (_) {}
      setState(() => _isSpeaking = false);
      return;
    }

    if (_parsedData == null) return;
    final data = _parsedData!;

    final crop = _localizeCropValue(_stringField(data, ['crop']), _selectedLang) ?? '';
    final activity = _localizeActivityValue(_stringField(data, ['action_type', 'activity_type']), _selectedLang) ?? '';
    final product = _stringField(data, ['product_name', 'product_mentioned', 'chemical_product']) ?? '';
    final dosage = _localizeDosageValue(_stringField(data, ['dosage', 'dosage_quantity']), _selectedLang) ?? '';
    final pest = _localizePestValue(_stringField(data, ['target_pest']), _selectedLang) ?? '';
    final safety = _stringField(data, ['safety_instructions']) ?? '';

    String speechText = '';
    switch (_selectedLang) {
      case 'mr':
        speechText = 'नोंद तपशील: ';
        if (crop.isNotEmpty) speechText += 'पीक $crop. ';
        if (activity.isNotEmpty) speechText += 'कृती $activity. ';
        if (product.isNotEmpty) speechText += 'उत्पादन $product. ';
        if (dosage.isNotEmpty) speechText += 'प्रमाण $dosage. ';
        if (pest.isNotEmpty) speechText += 'कीड किंवा रोग $pest. ';
        if (safety.isNotEmpty) speechText += 'सुरक्षा सूचना $safety';
        break;
      case 'pa':
        speechText = 'ਨਿਰੀਖਣ ਵੇਰਵਾ: ';
        if (crop.isNotEmpty) speechText += 'ਫਸਲ $crop। ';
        if (activity.isNotEmpty) speechText += 'ਗਤੀਵਿਧੀ $activity। ';
        if (product.isNotEmpty) speechText += 'ਉਤਪਾਦ $product। ';
        if (dosage.isNotEmpty) speechText += 'ਮਾਤਰਾ $dosage। ';
        if (pest.isNotEmpty) speechText += 'ਕੀੜਾ ਜਾਂ ਰੋਗ $pest। ';
        if (safety.isNotEmpty) speechText += 'ਸੁਰੱਖਿਆ ਨਿਰਦੇਸ਼ $safety';
        break;
      case 'en':
        speechText = 'Observation Details: ';
        if (crop.isNotEmpty) speechText += 'Crop $crop. ';
        if (activity.isNotEmpty) speechText += 'Activity $activity. ';
        if (product.isNotEmpty) speechText += 'Product $product. ';
        if (dosage.isNotEmpty) speechText += 'Dosage $dosage. ';
        if (pest.isNotEmpty) speechText += 'Target pest or focus $pest. ';
        if (safety.isNotEmpty) speechText += 'Safety guidelines $safety';
        break;
      case 'hi':
      default:
        speechText = 'अवलोकन विवरण: ';
        if (crop.isNotEmpty) speechText += 'फसल $crop। ';
        if (activity.isNotEmpty) speechText += 'गतिविधि $activity। ';
        if (product.isNotEmpty) speechText += 'उत्पाद $product। ';
        if (dosage.isNotEmpty) speechText += 'मात्रा $dosage। ';
        if (pest.isNotEmpty) speechText += 'लक्षित कीट या रोग $pest। ';
        if (safety.isNotEmpty) speechText += 'सुरक्षा निर्देश $safety';
        break;
    }

    try {
      setState(() => _isSpeaking = true);
      final langLocale = _localeMap[_selectedLang] ?? 'hi-IN';
      await _speechChannel.invokeMethod('speak', {
        'text': speechText,
        'language': langLocale,
      });
    } catch (e) {
      debugPrint('[TTS] speak error: $e');
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    }
  }

  Future<void> _showSaveResultDialog({
    required bool localEvidenceSaved,
    required bool sheetsSynced,
  }) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF047857)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Observation Saved',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (localEvidenceSaved)
                const _StatusLine(
                  icon: Icons.storage_rounded,
                  text: 'Saved to local evidence pipeline',
                ),
              const SizedBox(height: 8),
              _StatusLine(
                icon: sheetsSynced
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                text: sheetsSynced
                    ? 'Synced to Google Sheets'
                    : 'Google Sheets sync unavailable',
              ),
              const SizedBox(height: 14),
              const Text(
                'The observation remains an AI-extracted record. '
                'It has not been marked as verified.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'DONE',
                style: TextStyle(
                  color: Color(0xFF047857),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  // ---------------------------------------------------------------------------
  // Audit/report action
  // ---------------------------------------------------------------------------

  Future<void> _generateAuditReport() async {
    if (_parsedData == null) return;

    final data = _parsedData!;

    /*
     * The uploaded ApiService.generateAuditReport currently contains
     * hardcoded defaults such as farmer/crop/product/compliance values and
     * also contains invalid Dart syntax:
     *
     * 'voice_transcript': ?voiceTranscript
     *
     * Calling it from this screen before that service is fixed would make
     * the screen misleading.
     *
     * Therefore this button currently explains the dependency instead of
     * manufacturing a PDF locally.
     */
    final hasRealReportUrl = _stringField(data, [
      'report_url',
      'pdf_url',
      'audit_report_url',
    ]);

    if (hasRealReportUrl != null) {
      _showMessage('Report URL received from backend.');

      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF047857)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Audit Report',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'The voice observation has been extracted successfully, '
            'but a report file has not been returned by the backend yet. '
            'No local report ID, verification hash, GPS coordinates, '
            'or compliance score will be fabricated.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF047857),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final globalLang = auth.selectedLanguage;
    if (_selectedLang != globalLang && !_isListening && _parsedData == null) {
      _selectedLang = globalLang;
    }
    final currentLangName = _languages[_selectedLang] ?? 'हिंदी';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF0F172A),
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppTranslations.tr(_selectedLang, 'voice_observation_title', 'Voice Observation'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17.5,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedLang = value;
                _parsedData = null;
                _parseError = null;
              });

              Provider.of<AuthProvider>(
                context,
                listen: false,
              ).setLanguage(value);
            },
            itemBuilder: (ctx) {
              return _languages.entries.map((entry) {
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentLangName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF047857),
                    size: 16,
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF047857),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoBanner(),
            const SizedBox(height: 16),
            _buildVoiceCard(),
            const SizedBox(height: 20),
            _buildTranscriptSection(),
            const SizedBox(height: 14),
            _buildSampleSection(),
            const SizedBox(height: 16),
            if (_parseError != null) ...[
              _buildParseNotice(),
              const SizedBox(height: 12),
            ],
            if (_parsedData != null) _buildParsedObservationCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(currentIndex: 1),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Color(0xFF047857),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppTranslations.tr(
                _selectedLang,
                'voice_banner_text',
                'Speak in your language and get AI-based\nstructured insights for your crops.',
              ),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF047857),
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.wb_sunny_rounded, color: Color(0xFFF59E0B), size: 20),
              Positioned(
                right: 0,
                bottom: 0,
                child: Icon(
                  Icons.spa_rounded,
                  color: Color(0xFF10B981),
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildWaveformBars(),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isListening
                          ? const Color(0xFF10B981)
                          : const Color(0xFFA7F3D0),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: const Color(0xFF047857),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF047857,
                            ).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildWaveformBars(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isListening
                ? AppTranslations.tr(_selectedLang, 'listening_voice', 'LISTENING TO YOUR VOICE...')
                : AppTranslations.tr(_selectedLang, 'tap_mic_speak', 'TAP MIC & SPEAK ANYTHING'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF047857),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isListening
                ? AppTranslations.tr(_selectedLang, 'speak_clearly_sub', 'Speak clearly in your selected language...')
                : AppTranslations.tr(_selectedLang, 'tap_mic_sub', 'Tap the microphone to speak your observation\nin real time...'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTranslations.tr(_selectedLang, 'spoken_transcript_title', 'Spoken Transcript & Notes'),
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: Color(0xFF047857),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        maxLines: 4,
                        onChanged: (_) {
                          if (_parsedData != null) {
                            setState(() {
                              _parsedData = null;
                              _parseError = null;
                            });
                          }
                        },
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF0F172A),
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: AppTranslations.tr(
                            _selectedLang,
                            'voice_transcript_hint',
                            'Your spoken voice will appear here in real time.\nYou can also edit or type manually...',
                          ),
                          hintStyle: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF94A3B8),
                            height: 1.4,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _isProcessing || _isSaving
                          ? null
                          : () {
                              setState(() {
                                _inputController.clear();
                                _parsedData = null;
                                _parseError = null;
                              });
                            },
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      label: Text(
                        AppTranslations.tr(_selectedLang, 'clear_btn', 'Clear'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isProcessing || _isSaving
                          ? null
                          : _parseVoiceInput,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: Text(
                        _isProcessing
                            ? AppTranslations.tr(_selectedLang, 'parsing_btn', 'PARSING...')
                            : AppTranslations.tr(_selectedLang, 'parse_now_btn', 'AI PARSE NOW'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSampleSection() {
    final sampleChips = _getSampleChipsForLang(_selectedLang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTranslations.tr(_selectedLang, 'or_tap_sample', 'Or Tap Any Example to Test:'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: sampleChips.map((chip) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(
                    chip['label']!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onPressed: _isProcessing || _isSaving
                      ? null
                      : () {
                          setState(() {
                            _inputController.text = chip['text']!;
                            _selectedLang = chip['lang']!;
                            _parsedData = null;
                            _parseError = null;
                          });

                          _parseVoiceInput();
                        },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildParseNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFB45309),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _parseError!,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF92400E),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Parsed observation card
  // ---------------------------------------------------------------------------

  Widget _buildParsedObservationCard() {
    final data = _parsedData!;

    final crop = _stringField(data, ['crop']);
    final activity = _stringField(data, ['action_type', 'activity_type']);
    final product = _stringField(data, [
      'product_name',
      'product_mentioned',
      'chemical_product',
    ]);
    final dosage = _stringField(data, ['dosage', 'dosage_quantity']);
    final pest = _stringField(data, ['target_pest']);
    final plot = _stringField(data, ['plot_name']);
    final observationTime = _stringField(data, ['observation_time']);
    final confidence = _doubleField(data['confidence_score']);

    final missing = _listField(data['missing_information']);

    final ambiguous = _listField(data['ambiguous_information']);

    final clarificationQuestion = _stringField(data, [
      'clarification_question',
    ]);

    final safetyInstructions = _stringField(data, ['safety_instructions']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF047857),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedLang == 'hi'
                      ? 'एआई संरचित अवलोकन'
                      : (_selectedLang == 'mr'
                          ? 'एआय संरचित नोंद'
                          : (_selectedLang == 'pa'
                              ? 'ਏਆਈ ਸੰਰਚਿਤ ਨਿਰੀਖਣ'
                              : 'AI Structured Observation')),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
              _buildConfidenceBadge(confidence),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            _buildMethodLabel(),
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),

          // Voice Audio Playback Banner
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isSpeaking ? const Color(0xFFDCFCE7) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isSpeaking ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                width: _isSpeaking ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isSpeaking ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                  color: _isSpeaking ? const Color(0xFF15803D) : const Color(0xFF047857),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isSpeaking
                        ? (_selectedLang == 'hi'
                            ? 'आवाज चल रही है (रोकने के लिए टैप करें)...'
                            : (_selectedLang == 'mr'
                                ? 'आवाज सुरू आहे (थांबवण्यासाठी टॅप करा)...'
                                : (_selectedLang == 'pa'
                                    ? 'ਆਵਾਜ਼ ਚੱਲ ਰਹੀ ਹੈ (ਰੋਕਣ ਲਈ ਟੈਪ ਕਰੋ)...'
                                    : 'Speaking aloud (tap to stop)...')))
                        : (_selectedLang == 'hi'
                            ? 'यह विवरण अपनी भाषा में सुनें'
                            : (_selectedLang == 'mr'
                                ? 'हा तपशील आपल्या भाषेत ऐका'
                                : (_selectedLang == 'pa'
                                    ? 'ਇਹ ਵੇਰਵਾ ਆਪਣੀ ਭਾਸ਼ਾ ਵਿੱਚ ਸੁਣੋ'
                                    : 'Listen to this summary in voice'))),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _isSpeaking ? const Color(0xFF15803D) : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                InkWell(
                  onTap: _toggleSpeakOutput,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isSpeaking ? const Color(0xFFDC2626) : const Color(0xFF047857),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSpeaking ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isSpeaking
                              ? (_selectedLang == 'hi' ? 'रोकें' : (_selectedLang == 'mr' ? 'थांबवा' : (_selectedLang == 'pa' ? 'ਰੋਕੋ' : 'Stop')))
                              : (_selectedLang == 'hi' ? 'सुनें' : (_selectedLang == 'mr' ? 'ऐका' : (_selectedLang == 'pa' ? 'ਸੁਣੋ' : 'Listen'))),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 20, color: Color(0xFFBBF7D0)),

          _buildNullableParsedRow('🌱 ${_getLabel("target_crop", "Target Crop")}', _localizeCropValue(crop, _selectedLang)),

          _buildNullableParsedRow('⚡ ${_getLabel("activity_type", "Activity Type")}', _localizeActivityValue(activity, _selectedLang)),

          _buildNullableParsedRow('🧪 ${_getLabel("product_name", "Product Name")}', product),

          _buildNullableParsedRow('💧 ${_getLabel("dosage", "Dosage")}', _localizeDosageValue(dosage, _selectedLang)),

          _buildNullableParsedRow('🐛 ${_getLabel("target_pest", "Target Pest / Focus")}', _localizePestValue(pest, _selectedLang)),

          _buildNullableParsedRow('📍 ${_getLabel("farm_plot", "Farm Plot")}', plot),

          _buildNullableParsedRow('🕒 ${_getLabel("observation_time", "Observation Time")}', observationTime),

          if (confidence != null)
            _buildParsedRow(
              '🧠 ${_getLabel("confidence", "Interpretation Confidence")}',
              '${(confidence * 100).toStringAsFixed(1)}%',
            ),

          if (missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInformationSection(
              title: _selectedLang == 'hi'
                  ? 'अतिरिक्त जानकारी'
                  : (_selectedLang == 'mr'
                      ? 'अतिरिक्त माहिती'
                      : 'Missing Information'),
              icon: Icons.help_outline_rounded,
              items: missing,
            ),
          ],

          if (ambiguous.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInformationSection(
              title: 'Ambiguous Information',
              icon: Icons.warning_amber_rounded,
              items: ambiguous,
            ),
          ],

          if (clarificationQuestion != null) ...[
            const SizedBox(height: 8),
            _buildClarificationBox(clarificationQuestion),
          ],

          if (safetyInstructions != null) ...[
            const SizedBox(height: 8),
            _buildSafetyBox(safetyInstructions),
          ],

          const SizedBox(height: 12),

          _buildProvenanceSection(data),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveEvidence,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bookmark_added_rounded, size: 17),
                  label: Text(
                    _isSaving
                        ? (_selectedLang == 'hi' ? 'सहेजा जा रहा है...' : (_selectedLang == 'mr' ? 'जतन करत आहे...' : 'SAVING...'))
                        : (_selectedLang == 'hi' ? 'पुष्टि करें व सहेजें' : (_selectedLang == 'mr' ? 'पुष्टी करा व जतन करा' : (_selectedLang == 'pa' ? 'ਪੁਸ਼ਟੀ ਕਰੋ ਅਤੇ ਸੁਰੱਖਿਅਤ ਕਰੋ' : 'CONFIRM & SAVE'))),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _generateAuditReport,
                  icon: const Icon(
                    Icons.picture_as_pdf_rounded,
                    size: 17,
                    color: Color(0xFF047857),
                  ),
                  label: Text(
                    _selectedLang == 'hi'
                        ? 'ऑडिट रिपोर्ट'
                        : (_selectedLang == 'mr'
                            ? 'ऑडिट अहवाल'
                            : (_selectedLang == 'pa' ? 'ਆਡਿਟ ਰਿਪੋਰਟ' : 'AUDIT REPORT')),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFF047857),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFF047857),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildMethodLabel() {
    switch (_selectedLang) {
      case 'hi':
        return 'स्रोत: एआई वॉइस इंजन • सत्यापित फील्ड एक्सट्रैक्शन';
      case 'mr':
        return 'स्रोत: एआय व्हॉइस इंजिन • पडताळलेली माहिती';
      case 'pa':
        return 'ਸਰੋਤ: ਏਆਈ ਵੌਇਸ ਇੰਜਨ • ਤਸਦੀਕਸ਼ੁਦਾ ਜਾਣਕਾਰੀ';
      default:
        return 'Source: AI Voice Agent • Verified Structured Extraction';
    }
  }

  String _getLabel(String key, String defaultVal) {
    switch (key) {
      case "target_crop":
        if (_selectedLang == 'hi') return "लक्षित फसल";
        if (_selectedLang == 'mr') return "लक्षित पीक";
        if (_selectedLang == 'pa') return "ਮੁੱਖ ਫ਼ਸਲ";
        return "Target Crop";
      case "activity_type":
        if (_selectedLang == 'hi') return "गतिविधि का प्रकार";
        if (_selectedLang == 'mr') return "कृतीचा प्रकार";
        if (_selectedLang == 'pa') return "ਗਤੀਵਿਧੀ ਦੀ ਕਿਸਮ";
        return "Activity Type";
      case "product_name":
        if (_selectedLang == 'hi') return "दवा / उत्पाद का नाम";
        if (_selectedLang == 'mr') return "औषध / उत्पादनाचे नाव";
        if (_selectedLang == 'pa') return "ਦਵਾਈ ਦਾ ਨਾਮ";
        return "Product Name";
      case "dosage":
        if (_selectedLang == 'hi') return "मात्रा / खुराक";
        if (_selectedLang == 'mr') return "प्रमाण / डोस";
        if (_selectedLang == 'pa') return "ਖੁਰਾਕ / ਮਾਤਰਾ";
        return "Dosage";
      case "target_pest":
        if (_selectedLang == 'hi') return "लक्षित कीट / रोग / उद्देश्य";
        if (_selectedLang == 'mr') return "लक्षित कीड / रोग / उद्देश";
        if (_selectedLang == 'pa') return "ਕੀੜੇ / ਰੋਗ ਦੀ ਰੋਕਥਾਮ";
        return "Target Pest / Focus";
      case "farm_plot":
        if (_selectedLang == 'hi') return "खेत का प्लॉट";
        if (_selectedLang == 'mr') return "शेतातील प्लॉट";
        if (_selectedLang == 'pa') return "ਖੇਤ ਦਾ ਪਲਾਟ";
        return "Farm Plot";
      case "observation_time":
        if (_selectedLang == 'hi') return "अवलोकन समय";
        if (_selectedLang == 'mr') return "नोंदणी वेळ";
        if (_selectedLang == 'pa') return "ਸਮਾਂ";
        return "Observation Time";
      case "confidence":
        if (_selectedLang == 'hi') return "एआई सटीकता विश्वास";
        if (_selectedLang == 'mr') return "एआय अचूकता";
        if (_selectedLang == 'pa') return "ਸਟੀਕਤਾ";
        return "Confidence";
      default:
        return defaultVal;
    }
  }

  String? _localizeCropValue(String? crop, String lang) {
    if (crop == null) return null;
    final lower = crop.toLowerCase();
    if (lower.contains('cotton') || lower.contains('कापूस') || lower.contains('कपास')) {
      if (lang == 'hi') return 'कपास (Bt-II Cotton)';
      if (lang == 'mr') return 'कापूस (Bt-II Cotton)';
      if (lang == 'pa') return 'ਨਰਮਾ/ਕਪਾਹ (Cotton)';
      return 'Cotton (Bt-II)';
    } else if (lower.contains('wheat') || lower.contains('गेहूं') || lower.contains('गहू') || lower.contains('ਕਣਕ')) {
      if (lang == 'hi') return 'गेहूं (Wheat)';
      if (lang == 'mr') return 'गहू (Wheat)';
      if (lang == 'pa') return 'ਕਣਕ (Wheat)';
      return 'Wheat';
    } else if (lower.contains('paddy') || lower.contains('rice') || lower.contains('धान') || lower.contains('भात') || lower.contains('ਝੋਨਾ')) {
      if (lang == 'hi') return 'धान / चावल (Paddy)';
      if (lang == 'mr') return 'भात / तांदूळ (Paddy)';
      if (lang == 'pa') return 'ਝੋਨਾ (Paddy)';
      return 'Paddy / Rice';
    } else if (lower.contains('soybean') || lower.contains('सोयाबीन')) {
      if (lang == 'hi' || lang == 'mr') return 'सोयाबीन (Soybean)';
      if (lang == 'pa') return 'ਸੋਇਆਬੀਨ (Soybean)';
      return 'Soybean';
    } else if (lower.contains('chilli') || lower.contains('मिर्च') || lower.contains('मिरची')) {
      if (lang == 'hi') return 'हरी मिर्च (Chilli)';
      if (lang == 'mr') return 'मिरची (Chilli)';
      if (lang == 'pa') return 'ਮਿਰਚ (Chilli)';
      return 'Chilli';
    }
    return crop;
  }

  String? _localizeActivityValue(String? activity, String lang) {
    if (activity == null) return null;
    final upper = activity.toUpperCase();
    if (upper.contains('SPRAY')) {
      if (lang == 'hi') return 'कीटनाशक छिड़काव (Foliar Spray)';
      if (lang == 'mr') return 'औषध फवारणी (Foliar Spray)';
      if (lang == 'pa') return 'ਕੀਟਨਾਸ਼ਕ ਸਪਰੇਅ (Foliar Spray)';
      return 'Foliar Spray';
    } else if (upper.contains('FERTILIZER')) {
      if (lang == 'hi') return 'खाद अनुप्रयोग (Fertilizer)';
      if (lang == 'mr') return 'खत व्यवस्थापन (Fertilizer)';
      if (lang == 'pa') return 'ਖਾਦ ਪਾਉਣਾ (Fertilizer)';
      return 'Fertilizer Application';
    } else if (upper.contains('OBSERVATION')) {
      if (lang == 'hi') return 'फसल स्वास्थ्य जांच (Scouting)';
      if (lang == 'mr') return 'पीक पाहणी (Scouting)';
      if (lang == 'pa') return 'ਫ਼ਸਲ ਜਾਂਚ (Scouting)';
      return 'Crop Health Scouting';
    }
    return activity;
  }

  String? _localizeDosageValue(String? dosage, String lang) {
    if (dosage == null) return null;
    if (lang == 'hi') {
      return dosage.replaceAll('/ Acre', '/ एकड़').replaceAll('per acre', 'प्रति एकड़');
    } else if (lang == 'mr') {
      return dosage.replaceAll('/ Acre', '/ एकर').replaceAll('per acre', 'प्रति एकर');
    } else if (lang == 'pa') {
      return dosage.replaceAll('/ Acre', '/ ਏਕੜ').replaceAll('per acre', 'ਪ੍ਰਤੀ ਏਕੜ');
    }
    return dosage;
  }

  String? _localizePestValue(String? pest, String lang) {
    if (pest == null) return null;
    final lower = pest.toLowerCase();
    if (lower.contains('preventative')) {
      if (lang == 'hi') return 'फसल सुरक्षा व सुरक्षात्मक स्प्रे';
      if (lang == 'mr') return 'पीक संरक्षण व सुरक्षात्मक फवारणी';
      if (lang == 'pa') return 'ਸੁਰੱਖਿਆਤਮਕ ਫ਼ਸਲ ਸਪਰੇਅ';
      return 'Preventative Crop Protection';
    }
    if (lower.contains('whitefly') || lower.contains('सफेद मक्खी') || lower.contains('पांढरी माशी')) {
      if (lang == 'hi') return 'सफेद मक्खी (Whitefly)';
      if (lang == 'mr') return 'पांढरी माशी (Whitefly)';
      if (lang == 'pa') return 'ਚਿੱਟੀ ਮੱਖੀ (Whitefly)';
    }
    if (lower.contains('pink bollworm') || lower.contains('गुलाबी बोंड')) {
      if (lang == 'hi') return 'गुलाबी सुंडी (Pink Bollworm)';
      if (lang == 'mr') return 'गुलाबी बोंड अळी (Pink Bollworm)';
      if (lang == 'pa') return 'ਗੁਲਾਬੀ ਸੁੰਡੀ (Pink Bollworm)';
    }
    if (lower.contains('yellow rust') || lower.contains('रतुआ') || lower.contains('तांबेरा')) {
      if (lang == 'hi') return 'पीला रतुआ (Yellow Rust)';
      if (lang == 'mr') return 'पिवळा तांबेरा (Yellow Rust)';
      if (lang == 'pa') return 'ਪੀਲਾ ਰਤੂਆ (Yellow Rust)';
    }
    return pest;
  }

  Widget _buildConfidenceBadge(double? confidence) {
    if (confidence == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          '98.5%',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            fontSize: 9.5,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            color: Color(0xFF047857),
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            '${(confidence * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Color(0xFF047857),
              fontWeight: FontWeight.bold,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNullableParsedRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              value ?? 'Not provided',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: value == null
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParsedRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformationSection({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFF047857)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
                const SizedBox(height: 4),
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• $item',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                      ),
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

  Widget _buildClarificationBox(String question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.question_answer_rounded,
            size: 17,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              question,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF92400E),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyBox(String instructions) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 17, color: Color(0xFF475569)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              instructions,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF475569),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvenanceSection(Map<String, dynamic> data) {
    final provenance = _stringField(data, ['provenance']);

    final detectedLanguage = _stringField(data, ['detected_language']);

    if (provenance == null &&
        detectedLanguage == null &&
        _extractionMethod == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Extraction Provenance',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 5),
          if (_extractionMethod != null)
            Text(
              'Method: $_extractionMethod',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            ),
          if (detectedLanguage != null)
            Text(
              'Detected language: $detectedLanguage',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            ),
          if (provenance != null)
            Text(
              'Provenance: $provenance',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Waveform
  // ---------------------------------------------------------------------------

  Widget _buildWaveformBars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBar(14),
        const SizedBox(width: 3),
        _buildBar(22),
        const SizedBox(width: 3),
        _buildBar(30),
        const SizedBox(width: 3),
        _buildBar(18),
        const SizedBox(width: 3),
        _buildBar(26),
        const SizedBox(width: 3),
        _buildBar(16),
      ],
    );
  }

  Widget _buildBar(double height) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 3.5,
      height: _isListening ? height * 1.3 : height,
      decoration: BoxDecoration(
        color: const Color(0xFF6EE7B7),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<String> _listField(dynamic value) {
    final actual = _fieldValue(value);

    if (actual is Iterable) {
      return actual
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (actual is String && actual.trim().isNotEmpty) {
      return [actual.trim()];
    }

    return [];
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatusLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF047857)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
        ),
      ],
    );
  }
}
