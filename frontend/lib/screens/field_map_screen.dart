import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../core/providers/farm_provider.dart';
import '../core/providers/evidence_provider.dart';

class FieldMapScreen extends StatefulWidget {
  const FieldMapScreen({super.key});

  @override
  State<FieldMapScreen> createState() => _FieldMapScreenState();
}

class _FieldMapScreenState extends State<FieldMapScreen> {
  bool _showNdvi = true;
  final String _selectedPlot = "Plot North-04";

  @override
  Widget build(BuildContext context) {
    final farmProv = Provider.of<FarmProvider>(context);
    final evProv = Provider.of<EvidenceProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text(
          "Geospatial Field Map",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          Row(
            children: [
              const Text(
                "NDVI Layer",
                style: TextStyle(fontSize: 11, color: Colors.white70),
              ),
              Switch(
                value: _showNdvi,
                activeThumbColor: AppColors.primaryAccent,
                onChanged: (v) => setState(() => _showNdvi = v),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Interactive Geospatial Canvas Simulator
          CustomPaint(
            size: Size.infinite,
            painter: FieldMapPainter(showNdvi: _showNdvi),
          ),

          // Plot Marker Overlay Buttons
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Farm: ${farmProv.selectedFarm?.name ?? 'Sahyadri Bio-Cluster'} (${farmProv.selectedFarm?.totalAcres ?? 12.5} Ac)",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Evidence Pins on Canvas
          Positioned(
            top: 180,
            left: 140,
            child: _buildMapPin(
              "EV-8812 (Post-Spray)",
              Icons.camera_alt_rounded,
              AppColors.primary,
            ),
          ),
          Positioned(
            top: 280,
            left: 220,
            child: _buildMapPin(
              "EV-8810 (QR Bio-Neem)",
              Icons.qr_code_2_rounded,
              Colors.blue,
            ),
          ),
          Positioned(
            top: 360,
            left: 100,
            child: _buildMapPin(
              "EV-8813 (Rain Voice)",
              Icons.mic_rounded,
              Colors.purple,
            ),
          ),

          // Bottom Plot Inspector Card
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedPlot,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${evProv.evidenceList.isNotEmpty ? evProv.evidenceList.first.verificationScore.toStringAsFixed(1) : '98.6'}% Verified",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${farmProv.selectedFarm?.activeCrop ?? 'Cotton (Bt-II)'} • ${farmProv.selectedFarm?.totalAcres ?? 12.5} Acres • Logs: ${evProv.evidenceList.length}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Canopy NDVI: 0.79 (Healthy)",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        "Pest Pressure: Low (<2%)",
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentGold,
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
    );
  }

  Widget _buildMapPin(String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      ],
    );
  }
}

class FieldMapPainter extends CustomPainter {
  final bool showNdvi;

  FieldMapPainter({required this.showNdvi});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1;

    // Draw grid
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Plot 1 Polygon
    final plot1 = Path()
      ..moveTo(60, 120)
      ..lineTo(320, 140)
      ..lineTo(300, 320)
      ..lineTo(50, 280)
      ..close();

    final plotPaint = Paint()
      ..color = showNdvi
          ? const Color(0xFF059669).withValues(alpha: 0.45)
          : const Color(0xFF334155)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = AppColors.primaryAccent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(plot1, plotPaint);
    canvas.drawPath(plot1, borderPaint);

    // Plot 2 Polygon
    final plot2 = Path()
      ..moveTo(50, 300)
      ..lineTo(300, 340)
      ..lineTo(280, 520)
      ..lineTo(40, 480)
      ..close();

    final plotPaint2 = Paint()
      ..color = showNdvi
          ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
          : const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final borderPaint2 = Paint()
      ..color = AppColors.accentGold
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(plot2, plotPaint2);
    canvas.drawPath(plot2, borderPaint2);
  }

  @override
  bool shouldRepaint(covariant FieldMapPainter oldDelegate) =>
      oldDelegate.showNdvi != showNdvi;
}
