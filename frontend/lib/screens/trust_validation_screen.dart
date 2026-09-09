import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/services/api_service.dart';

class TrustValidationScreen extends StatefulWidget {
  const TrustValidationScreen({super.key});

  @override
  State<TrustValidationScreen> createState() => _TrustValidationScreenState();
}

class _TrustValidationScreenState extends State<TrustValidationScreen> {
  final _api = ApiService();

  // Preset Configurations
  final List<Map<String, dynamic>> _presets = [
    {
      "title": "1. Dose Mismatch (User Example)",
      "desc": "Voice = Bio-X 2 L/acre, Label = 1 L/acre",
      "crop": "Cotton",
      "nlp_product": "Bio-X",
      "nlp_dose": "2 L/acre",
      "vision_dose": "1 L/acre",
      "target_pest": "Whitefly",
      "wind_speed": 6.5,
      "rain_prob": 10.0,
      "color": const Color(0xFFF59E0B),
    },
    {
      "title": "2. Fully Validated & Compliant",
      "desc": "Tilt 200 ml/acre on Wheat Yellow Rust",
      "crop": "Wheat",
      "nlp_product": "Propiconazole 25% EC (Tilt)",
      "nlp_dose": "200 ml in 200L water / acre",
      "vision_dose": "200 ml/acre",
      "target_pest": "Yellow Rust",
      "wind_speed": 5.2,
      "rain_prob": 5.0,
      "color": const Color(0xFF047857),
    },
    {
      "title": "3. Adverse Weather Drift Risk",
      "desc": "High wind (22 km/h) exceeds 15 km/h limit",
      "crop": "Cotton",
      "nlp_product": "Bio-Neem",
      "nlp_dose": "400 ml/acre",
      "vision_dose": "400 ml/acre",
      "target_pest": "Whitefly",
      "wind_speed": 22.5,
      "rain_prob": 15.0,
      "color": const Color(0xFFEA580C),
    },
    {
      "title": "4. Chemical Incompatibility",
      "desc": "Fungicide (Tilt) applied for insect attack",
      "crop": "Wheat",
      "nlp_product": "Tilt",
      "nlp_dose": "200 ml/acre",
      "vision_dose": "200 ml/acre",
      "target_pest": "Whitefly",
      "wind_speed": 6.0,
      "rain_prob": 10.0,
      "color": const Color(0xFFDC2626),
    },
  ];

  int _selectedPreset = 0;
  bool _isLoading = false;
  Map<String, dynamic>? _validationResult;

  final _cropController = TextEditingController(text: "Cotton");
  final _nlpProductController = TextEditingController(text: "Bio-X");
  final _nlpDoseController = TextEditingController(text: "2 L/acre");
  final _visionDoseController = TextEditingController(text: "1 L/acre");
  final _pestController = TextEditingController(text: "Whitefly");
  final _windController = TextEditingController(text: "6.5");

  @override
  void initState() {
    super.initState();
    _applyPreset(0);
  }

  @override
  void dispose() {
    _cropController.dispose();
    _nlpProductController.dispose();
    _nlpDoseController.dispose();
    _visionDoseController.dispose();
    _pestController.dispose();
    _windController.dispose();
    super.dispose();
  }

  void _applyPreset(int index) {
    setState(() {
      _selectedPreset = index;
      final p = _presets[index];
      _cropController.text = p["crop"];
      _nlpProductController.text = p["nlp_product"];
      _nlpDoseController.text = p["nlp_dose"];
      _visionDoseController.text = p["vision_dose"];
      _pestController.text = p["target_pest"];
      _windController.text = p["wind_speed"].toString();
    });
    _runValidation();
  }

  Future<void> _runValidation() async {
    setState(() => _isLoading = true);

    try {
      final res = await _api.crossValidateEvidence(
        evidenceId: "EV-TEST-${DateTime.now().millisecondsSinceEpoch}",
        farmId: "farm-101",
        cropName: _cropController.text.trim(),
        nlpOutput: {
          "raw_transcript": "Sprayed ${_nlpProductController.text} at ${_nlpDoseController.text} on ${_cropController.text} for ${_pestController.text}.",
          "crop": _cropController.text.trim(),
          "action_type": "SPRAY",
          "product_mentioned": _nlpProductController.text.trim(),
          "dosage": _nlpDoseController.text.trim(),
          "target_pest": _pestController.text.trim(),
        },
        visionOutput: {
          "crop_detected": _cropController.text.trim(),
          "product_name": _nlpProductController.text.trim(),
          "label_dosage": _visionDoseController.text.trim(),
          "recommended_dosage": _visionDoseController.text.trim(),
          "disease_detected": _pestController.text.trim(),
        },
        weatherOutput: {
          "temperature_c": 27.5,
          "humidity_percent": 65.0,
          "wind_speed_kmh": double.tryParse(_windController.text.trim()) ?? 6.5,
          "precipitation_prob": 10.0,
          "delta_t_c": 4.5,
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _validationResult = res;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Trust & Validation Agent", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Agent #4 • Multi-Agent Consistency Inspector", style: TextStyle(fontSize: 11, color: AppColors.primary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Re-run Validation",
            onPressed: _isLoading ? null : _runValidation,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Explanation Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF064E3B), Color(0xFF047857)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF047857).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security_rounded, color: AppColors.accentGold, size: 24),
                      SizedBox(width: 8),
                      Text(
                        "Multi-Agent Consistency Engine",
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Receives outputs from NLP Agent + Vision Agent + Weather Agent. Cross-verifies dosages, crop compatibility, and drift conditions to flag anomalies before sealing.",
                    style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Presets Selector Header
            const Text(
              "Select Test Scenario Preset:",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),

            // Horizontal Presets Strip
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_presets.length, (idx) {
                  final p = _presets[idx];
                  final isSel = _selectedPreset == idx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _applyPreset(idx),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSel ? p["color"].withOpacity(0.12) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel ? p["color"] : const Color(0xFFE2E8F0),
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p["title"],
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: isSel ? p["color"] : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p["desc"],
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 18),

            // Live Cross-Agent Input Form Card
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
                  const Row(
                    children: [
                      Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
                      SizedBox(width: 6),
                      Text("Multi-Agent Input Parameters", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(child: _buildInput("Crop Name", _cropController, Icons.eco_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInput("Product Mentioned", _nlpProductController, Icons.science_rounded)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildInput("NLP Voice Dose", _nlpDoseController, Icons.mic_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInput("Vision Label Dose", _visionDoseController, Icons.photo_camera_rounded)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildInput("Target Pest", _pestController, Icons.bug_report_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInput("Wind Speed (km/h)", _windController, Icons.air_rounded, isNum: true)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _runValidation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.flash_on_rounded, size: 18),
                      label: Text(
                        _isLoading ? "RUNNING CROSS-VERIFICATION..." : "RUN TRUST & VALIDATION CHECK",
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Live Validation Output Card
            if (_validationResult != null) ...[
              _buildValidationResultCard(_validationResult!),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationResultCard(Map<String, dynamic> res) {
    final status = res['validation_status']?.toString() ?? 'validated';
    final compScore = (res['completeness_score'] as num?)?.toDouble() ?? 1.0;
    final consistency = res['consistency_status']?.toString() ?? 'consistent';
    final action = res['required_action']?.toString() ?? 'none';
    final flags = res['flags'] is List ? List<Map<String, dynamic>>.from(res['flags']) : [];

    final isValidated = status == 'validated';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isValidated ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isValidated ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status Badge
          Row(
            children: [
              Icon(
                isValidated ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: isValidated ? const Color(0xFF047857) : const Color(0xFFD97706),
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Validation Status: ${status.toUpperCase()}",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isValidated ? const Color(0xFF065F46) : const Color(0xFF92400E),
                      ),
                    ),
                    Text(
                      "Consistency: ${consistency.toUpperCase()} • Action: ${action.replaceAll('_', ' ').toUpperCase()}",
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  "Score: ${(compScore * 100).toInt()}%",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Structured Output Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricTile("completeness_score", compScore.toStringAsFixed(2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile("consistency_status", consistency),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile("required_action", action),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Flags Section
          if (flags.isNotEmpty) ...[
            Text(
              "Flags Detected (${flags.length}):",
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
            ),
            const SizedBox(height: 8),
            ...flags.map((f) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.flag_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (f['type'] ?? '').toString().toUpperCase(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              f['message']?.toString() ?? '',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Color(0xFF047857), size: 18),
                  SizedBox(width: 8),
                  Text(
                    "flags: [] (Zero anomalies detected across all agents)",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Raw JSON Inspector (Expandable)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text("View Raw JSON Output", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(res),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFA7F3D0)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String key, String val) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(key, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {bool isNum = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNum ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 16, color: AppColors.primary),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          ),
        ),
      ],
    );
  }
}
