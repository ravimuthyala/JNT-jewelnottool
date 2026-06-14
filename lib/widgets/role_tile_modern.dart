import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

class RoleTileModern extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconAsset;
  final bool selected;
  final VoidCallback onTap;

  const RoleTileModern({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconAsset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.zero,
          border: Border.all(
            color: selected
                ? AppColors.deepPlum
                : Colors.black.withOpacity(0.08),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ ICON ONLY (NO CONTAINER)
            SvgPicture.asset(
              iconAsset,
              width: 26,
              height: 26,
              colorFilter: ColorFilter.mode(
                AppColors.deepPlum,
                BlendMode.srcIn,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.black.withOpacity(0.6),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.check_circle,
                size: 18,
                color: AppColors.deepPlum,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
