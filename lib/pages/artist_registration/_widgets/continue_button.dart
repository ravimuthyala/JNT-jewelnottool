import '../../../theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'reg_helpers.dart';

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
      width: embedded ? null : double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: (enabled && !loading) ? onTap : null,
        style: regPrimaryButtonStyle(),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.snow,
                ),
              )
            : Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.snow,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Arial',
                  fontSize: 12,
                ),
              ),
      ),
    );

    if (embedded) return button;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: button,
    );
  }
}
