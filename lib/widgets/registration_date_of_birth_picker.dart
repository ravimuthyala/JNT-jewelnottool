import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'accessible_date_grid.dart';

Future<void> showRegistrationAgeIneligibleDialog({
  required BuildContext context,
}) {
  return showDialog<void>(
    context: context,
    barrierLabel: 'Age eligibility alert',
    builder: (dialogContext) => Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: 'Age eligibility alert',
      child: Dialog(
        backgroundColor: AppColors.snow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Container(
          color: AppColors.snow,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sorry, You are not eligible to create account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.blackCat,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Arial',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  autofocus: true,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blackCat,
                    foregroundColor: AppColors.snow,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Arial',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    ),
  );
}

/// Shows the accessible calendar-grid picker for date of birth. The
/// underlying registration field is directly typable too (see
/// `RegistrationInputUtils.formatDateOfBirth` / `tryParseMmDdYyyy`), so this
/// modal only needs to cover the tap-to-pick path -- no separate in-modal
/// keyboard-entry toggle is needed here anymore.
Future<DateTime?> showRegistrationDateOfBirthPicker({
  required BuildContext context,
  DateTime? initialDate,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final initial = initialDate ?? today;
  final clampedInitial = initial.isAfter(today) ? today : initial;

  return showAccessibleDatePickerDialog(
    context: context,
    fieldLabel: 'Date of Birth',
    firstDate: DateTime(1900),
    lastDate: today,
    initialSelectedDate: clampedInitial,
  );
}
