import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class SelectableRoleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const SelectableRoleTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.deepPlum : Colors.grey.shade300;
    final bgColor = selected ? AppColors.deepPlum.withValues(alpha: 0.08) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.zero,
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.deepPlum.withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.65),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
