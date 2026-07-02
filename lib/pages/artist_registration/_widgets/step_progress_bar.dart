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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Step indicators row ───────────────────────────────────────
          Row(
            children: List.generate(total * 2 - 1, (i) {
              if (i.isOdd) {
                // Connector line
                final stepBefore = (i ~/ 2) + 1;
                final isDone = stepBefore < current;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isDone ? AppColors.blackCat : AppColors.blackCat.withValues(alpha: 0.15),
                  ),
                );
              }

              final step = i ~/ 2 + 1;
              final isDone = step < current;
              final isActive = step == current;

              return _StepDot(
                step: step,
                isDone: isDone,
                isActive: isActive,
                label: step <= stepLabels.length ? stepLabels[step - 1] : '',
              );
            }),
          ),

          const SizedBox(height: 10),

          // ── Step label row ────────────────────────────────────────────
          Row(
            children: List.generate(total * 2 - 1, (i) {
              if (i.isOdd) return const Expanded(child: SizedBox.shrink());
              final step = i ~/ 2 + 1;
              final label = step <= stepLabels.length ? stepLabels[step - 1] : '';
              final isActive = step == current;
              return SizedBox(
                width: 56,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? AppColors.blackCat
                        : AppColors.blackCat.withValues(alpha: 0.4),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 10),

          // ── "Step X of Y · Section name" ─────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.blackCat,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Step $current of $total',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sectionSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blackCat.withValues(alpha: 0.65),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Thin progress fill bar ────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 3,
              backgroundColor: AppColors.blackCat.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.balletSlippers),
            ),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.step,
    required this.isDone,
    required this.isActive,
    required this.label,
  });

  final int step;
  final bool isDone;
  final bool isActive;
  final String label;

  @override
  Widget build(BuildContext context) {
    final Color bg = isDone
        ? AppColors.blackCat
        : isActive
            ? AppColors.balletSlippers
            : AppColors.blackCat.withValues(alpha: 0.08);

    final Color border = isDone || isActive
        ? AppColors.blackCat
        : AppColors.blackCat.withValues(alpha: 0.2);

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.4),
      ),
      alignment: Alignment.center,
      child: isDone
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : Text(
              '$step',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.blackCat : AppColors.blackCat.withValues(alpha: 0.35),
              ),
            ),
    );
  }
}
