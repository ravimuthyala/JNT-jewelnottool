import 'package:flutter/material.dart';

import '../models/client_request_v2.dart';
import '../theme/app_colors.dart';

class CompanyClientRequestCard extends StatelessWidget {
  const CompanyClientRequestCard({
    super.key,
    required this.request,
    required this.scale,
    required this.displayStatus,
    required this.needByLabel,
    required this.submittedLabel,
    this.acceptByLabel = '',
    required this.avatar,
    required this.previewImage,
    required this.onTap,
    this.showNfcChip = false,
  });

  final ClientRequestV2 request;
  final double scale;
  final String displayStatus;
  final String needByLabel;
  final String submittedLabel;
  final String acceptByLabel;
  final Widget avatar;
  final Widget previewImage;
  final VoidCallback onTap;
  final bool showNfcChip;

  @override
  Widget build(BuildContext context) {
    final displayName = request.sourceCollection == 'Company_Custom_Requests'
        ? (request.brandName.trim().isEmpty
              ? (request.clientName.trim().isEmpty
                    ? 'Brand Company'
                    : request.clientName.trim())
              : request.brandName.trim())
        : (request.clientName.trim().isEmpty
              ? 'Brand Company'
              : request.clientName.trim());
    return InkWell(
      borderRadius: BorderRadius.zero,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.snow,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.blackCatBorderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox(width: 36, height: 36, child: avatar),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14 * scale,
                      color: AppColors.blackCat,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.title.trim().isEmpty
                        ? 'Campaign'
                        : request.title.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13 * scale,
                      color: AppColors.blackCat.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const SizedBox(height: 6),
                  _field(
                    'Order #',
                    request.orderNumber.trim().isEmpty
                        ? '-'
                        : request.orderNumber.trim(),
                    labelWeight: FontWeight.w500,
                    valueWeight: FontWeight.w500,
                    italic: true,
                  ),
                  _field('Needed By', needByLabel),
                  const SizedBox(height: 10),
                  _field(
                    'Submitted Date',
                    submittedLabel,
                    labelWeight: FontWeight.w500,
                    valueWeight: FontWeight.w500,
                    italic: true,
                  ),
                  if (acceptByLabel.trim().isNotEmpty)
                    _field(
                      'Accept By',
                      acceptByLabel,
                      labelWeight: FontWeight.w500,
                      valueWeight: FontWeight.w500,
                      italic: true,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayStatus,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.blackCat,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Container(
                    height: 64,
                    width: 84,
                    color: Colors.black.withValues(alpha: 0.05),
                    child: previewImage,
                  ),
                ),
                if (showNfcChip) ...[
                  const SizedBox(height: 5),
                  Align(alignment: Alignment.centerRight, child: _nfcChip()),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    String value, {
    FontWeight labelWeight = FontWeight.w700,
    FontWeight valueWeight = FontWeight.w600,
    bool italic = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: labelWeight,
                fontSize: 13 * scale,
                color: AppColors.blackCat,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: valueWeight,
                fontSize: 13 * scale,
                color: AppColors.blackCat,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nfcChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: const BoxDecoration(
        color: AppColors.balletSlippers,
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        'NFC',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11 * scale,
          color: AppColors.blackCat,
          height: 1.05,
        ),
      ),
    );
  }
}
