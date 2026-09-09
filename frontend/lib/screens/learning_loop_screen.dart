import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class LearningLoopScreen extends StatefulWidget {
  const LearningLoopScreen({super.key});

  @override
  State<LearningLoopScreen> createState() => _LearningLoopScreenState();
}

class _LearningLoopScreenState extends State<LearningLoopScreen> {
  final _correctionController = TextEditingController();
  String _selectedModel = "Vision Agent (Pathology Classification)";
  double _rating = 4.5;
  bool _submitted = false;

  final List<String> _models = [
    "Vision Agent (Pathology Classification)",
    "Voice Agent (Multilingual NLP)",
    "Validation Agent (Geo & Weather Score)",
    "Efficacy Agent (Recovery Curves)",
  ];

  void _submitFeedback() {
    setState(() => _submitted = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Agronomist Feedback Logged into Pramaan Continuous Learning Loop!",
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          "AI Learning Feedback Loop",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.model_training_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Agronomist corrections refine the multi-agent AI ensemble for local micro-varieties and regional pest strains.",
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Select AI Agent to Calibrate",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedModel,
              items: _models
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m, style: const TextStyle(fontSize: 12.5)),
                    ),
                  )
                  .toList(),
              onChanged: (val) =>
                  setState(() => _selectedModel = val ?? _selectedModel),
            ),
            const SizedBox(height: 16),

            const Text(
              "AI Prediction Quality Rating",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _rating,
              min: 1.0,
              max: 5.0,
              divisions: 8,
              label: "$_rating Stars",
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _rating = val),
            ),
            const SizedBox(height: 16),

            const Text(
              "Expert Correction / Ground Truth Feedback",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _correctionController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    "Enter expert pathology diagnosis, dosage adjustment, or local pest variant notes...",
              ),
            ),
            if (_submitted) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF047857), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "✓ Feedback successfully synchronized with Pramaan Learning Ensemble.",
                        style: TextStyle(color: Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitFeedback,
                icon: const Icon(Icons.send_rounded),
                label: const Text("SUBMIT GROUND TRUTH CORRECTION"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
