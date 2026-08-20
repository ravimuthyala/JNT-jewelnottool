import 'package:add_2_calendar/add_2_calendar.dart' as add2cal;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import 'date_format_utils.dart';

enum _CalendarChoice { phone, google }

/// Shows a bottom sheet offering to add [dueDate] to the artist's phone
/// calendar or Google Calendar. No-op (just dismissible) if they decline.
Future<void> promptAddRequestToCalendar(
  BuildContext context, {
  required String title,
  required DateTime dueDate,
  String description = '',
  String location = '',
}) async {
  final choice = await showModalBottomSheet<_CalendarChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToCalendarSheet(dueDate: dueDate),
  );

  if (choice == null) return;
  if (!context.mounted) return;

  switch (choice) {
    case _CalendarChoice.phone:
      await _addToPhoneCalendar(
        context,
        title: title,
        description: description,
        location: location,
        dueDate: dueDate,
      );
    case _CalendarChoice.google:
      await _addToGoogleCalendar(
        context,
        title: title,
        description: description,
        location: location,
        dueDate: dueDate,
      );
  }
}

void _showCalendarError(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _addToPhoneCalendar(
  BuildContext context, {
  required String title,
  required String description,
  required String location,
  required DateTime dueDate,
}) async {
  final day = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final event = add2cal.Event(
    title: title,
    description: description,
    location: location,
    startDate: day,
    endDate: day,
    allDay: true,
  );
  try {
    final added = await add2cal.Add2Calendar.addEvent2Cal(event);
    if (!added) {
      _showCalendarError(
        context,
        'No calendar app found to add this event to.',
      );
    }
  } catch (e) {
    _showCalendarError(context, 'Could not open your calendar app: $e');
  }
}

Future<void> _addToGoogleCalendar(
  BuildContext context, {
  required String title,
  required String description,
  required String location,
  required DateTime dueDate,
}) async {
  // Google Calendar's all-day "dates" param uses an EXCLUSIVE end date, so
  // a single-day all-day event needs end = start + 1 day.
  final start = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final end = start.add(const Duration(days: 1));
  String fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}'
      '${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  final uri = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${fmt(start)}/${fmt(end)}',
    if (description.isNotEmpty) 'details': description,
    if (location.isNotEmpty) 'location': location,
  });

  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showCalendarError(context, 'Could not open Google Calendar.');
    }
  } catch (e) {
    _showCalendarError(context, 'Could not open Google Calendar: $e');
  }
}

class _AddToCalendarSheet extends StatelessWidget {
  const _AddToCalendarSheet({required this.dueDate});

  final DateTime dueDate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        namesRoute: true,
        label: 'Add to calendar',
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Request accepted!',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.blackCat,
                  fontFamily: 'Arial',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add the due date (${formatDateMdy(dueDate)}) to your calendar?',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.blackCat.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 16),
              _CalendarOptionButton(
                icon: Icons.smartphone_rounded,
                label: 'Add to Phone Calendar',
                onTap: () => Navigator.pop(context, _CalendarChoice.phone),
              ),
              const SizedBox(height: 10),
              _CalendarOptionButton(
                icon: Icons.event_rounded,
                label: 'Add to Google Calendar',
                onTap: () => Navigator.pop(context, _CalendarChoice.google),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Not now',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blackCat.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarOptionButton extends StatelessWidget {
  const _CalendarOptionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.snow,
          foregroundColor: AppColors.blackCat,
          side: BorderSide(color: AppColors.blackCat.withValues(alpha: 0.35)),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
