import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class ContinueButton extends StatelessWidget {
  const ContinueButton({
    super.key,
    required this.onTap,
    this.label = 'Continue',
    this.enabled = true,
    this.loading = false,
    this.embedded = false,
  });

  final VoidCallback onTap;
  final String label;
  final bool enabled;
  final bool loading;
  /// When true, skips the outer padded container (use when placed inside a Row).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: (enabled && !loading) ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blackCat,
          disabledBackgroundColor: AppColors.blackCatBorderLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
              )
            : Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
      ),
    );

    if (embedded) return button;

    return Container(
      color: AppColors.snow,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: button,
    );
  }
}
