import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

Future<void> showRegistrationAgeIneligibleDialog({
  required BuildContext context,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
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
                height: 46,
                child: ElevatedButton(
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
  );
}

Future<DateTime?> showRegistrationDateOfBirthPicker({
  required BuildContext context,
  DateTime? initialDate,
}) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime tempSelected = initialDate ?? today;

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Select date of birth',
      child: Dialog(
        backgroundColor: AppColors.snow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          color: AppColors.snow,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330, maxHeight: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.blackCat,
                    onPrimary: AppColors.snow,
                    surface: AppColors.snow,
                    onSurface: AppColors.blackCat,
                  ),
                  datePickerTheme: const DatePickerThemeData(
                    backgroundColor: AppColors.snow,
                    surfaceTintColor: AppColors.snow,
                    weekdayStyle: TextStyle(
                      color: AppColors.blackCat,
                      fontSize: 12,
                    ),
                    dayStyle: TextStyle(
                      color: AppColors.blackCat,
                      fontSize: 13,
                    ),
                    yearStyle: TextStyle(
                      color: AppColors.blackCat,
                      fontSize: 12,
                    ),
                    todayBorder: BorderSide(
                      color: AppColors.blackCat,
                      width: 1.5,
                    ),
                  ),
                ),
                // CalendarDatePicker's onDateChanged also fires when the user
                // only picks a year from the year grid (keeping today's
                // month/day) -- popping immediately there would never let
                // them go on to pick the month/day. So we just track the
                // latest selection here and only return it once the user
                // taps Confirm below.
                child: StatefulBuilder(
                  builder: (context, setDialogState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: CalendarDatePicker(
                          initialDate: tempSelected,
                          currentDate: today,
                          firstDate: DateTime(1900),
                          lastDate: today,
                          onDateChanged: (value) {
                            setDialogState(() => tempSelected = value);
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.blackCatLight,
                              foregroundColor: AppColors.snow,
                            ),
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.blackCat,
                              foregroundColor: AppColors.snow,
                            ),
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(tempSelected),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
