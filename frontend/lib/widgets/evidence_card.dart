import 'package:flutter/material.dart';
import '../../models/evidence_model.dart';

class EvidenceCard extends StatelessWidget {
  final EvidenceItem item;
  final VoidCallback onTap;

  const EvidenceCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  String _formatDate(String raw) {
    try {
      if (raw.contains('T')) {
        final dt = DateTime.parse(raw).toLocal();
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? 'PM' : 'AM';
        return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $hour:$minute $period";
      }
    } catch (_) {}
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    IconData typeIcon;
    Color iconBgColor;
    Color iconColor;

    if (item.evidenceType == 'VOICE_LOG') {
      typeIcon = Icons.mic_rounded;
      iconBgColor = const Color(0xFFF3E8FF);
      iconColor = const Color(0xFF7E22CE);
    } else if (item.evidenceType == 'PRODUCT_SCAN') {
      typeIcon = Icons.qr_code_2_rounded;
      iconBgColor = const Color(0xFFE0F2FE);
      iconColor = const Color(0xFF0284C7);
    } else if (item.evidenceType == 'CROP_IMAGE') {
      typeIcon = Icons.camera_alt_rounded;
      iconBgColor = const Color(0xFFECFDF5);
      iconColor = const Color(0xFF059669);
    } else {
      typeIcon = Icons.eco_rounded;
      iconBgColor = const Color(0xFFFEF3C7);
      iconColor = const Color(0xFFD97706);
    }

    final scoreStr = item.verificationScore.toStringAsFixed(1);
    final isVerified = item.verificationStatus == 'VERIFIED' || item.verificationScore >= 80;
    final isFlagged = item.verificationStatus == 'FLAGGED' || item.flags.isNotEmpty;

    final badgeBg = isFlagged
        ? const Color(0xFFFEF2F2)
        : isVerified
            ? const Color(0xFFECFDF5)
            : const Color(0xFFFFFBEB);

    final badgeColor = isFlagged
        ? const Color(0xFFDC2626)
        : isVerified
            ? const Color(0xFF059669)
            : const Color(0xFFD97706);

    final badgeIcon = isFlagged
        ? Icons.error_outline_rounded
        : isVerified
            ? Icons.check_circle_rounded
            : Icons.hourglass_top_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Title/Subtitle + Score Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(typeIcon, color: iconColor, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title.isNotEmpty ? item.title : "Crop Observation",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "${item.cropName} • ${item.location.village.isNotEmpty ? item.location.village : 'Plot North-04'}",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.2), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, size: 14, color: badgeColor),
                          const SizedBox(width: 4),
                          Text(
                            "$scoreStr%",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description Text
                Text(
                  item.description.isNotEmpty
                      ? item.description
                      : "Verified field activity and crop diagnosis log.",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF334155),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Bottom Metadata Row: Timestamp + Product Chip + Chevron
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Text(
                      _formatDate(item.timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.productName != null && item.productName!.isNotEmpty) ...[
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                            ),
                            child: Text(
                              item.productName!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF047857),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const Spacer(),
                    ],
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
