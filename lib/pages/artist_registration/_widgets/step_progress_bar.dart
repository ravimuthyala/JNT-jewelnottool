import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.current,
    required this.total,
    required this.stepLabels,
    required this.sectionSubtitle,
  });

  final int current;
  final int total;
  final List<String> stepLabels;
  final String sectionSubtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.snow,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(total * 2 - 1, (index) {
              if (index.isOdd) {
                final stepBefore = (index ~/ 2) + 1;
                final isDone = stepBefore < current;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      height: 1.5,
                      color: isDone
                          ? AppColors.blackCat.withValues(alpha: 0.55)
                          : AppColors.blackCat.withValues(alpha: 0.18),
                    ),
                  ),
                );
              }

              final step = (index ~/ 2) + 1;
              final isDone = step < current;
              final isActive = step == current;
              final label = step <= stepLabels.length ? stepLabels[step - 1] : '';

              return SizedBox(
                width: 48,
                child: _StepNode(
                  step: step,
                  label: label,
                  isDone: isDone,
                  isActive: isActive,
                ),
              );
            }),
          ),
          if (sectionSubtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              sectionSubtitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Arial',
                color: AppColors.blackCat.withValues(alpha: 0.68),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.step,
    required this.label,
    required this.isDone,
    required this.isActive,
  });

  final int step;
  final String label;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final bool emphasize = isDone || isActive;
    final Color fill = emphasize ? AppColors.blackCat : AppColors.alabaster;
    final Color textColor = emphasize ? AppColors.snow : AppColors.blackCat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: isDone
              ? const Icon(Icons.check, size: 15, color: AppColors.snow)
              : Text(
                  '$step',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Arial',
                    color: textColor,
                  ),
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: Text(
            label,
            textAlign: TextAlign.center,
            softWrap: true,
            style: TextStyle(
              fontSize: 9,
              height: 1.35,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              fontFamily: 'Arial',
              color: AppColors.blackCat.withValues(alpha: isActive ? 1 : 0.72),
            ),
          ),
        ),
      ],
    );
  }
}
