import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CommunicationPreferenceSection extends StatelessWidget {
  const CommunicationPreferenceSection({
    super.key,
    required this.emailNotifications,
    required this.smsNotifications,
    required this.onEmailChanged,
    required this.onSmsChanged,
  });

  final bool emailNotifications;
  final bool smsNotifications;
  final ValueChanged<bool> onEmailChanged;
  final ValueChanged<bool> onSmsChanged;

  static const double _titleFs = 16;
  static const double _labelFs = 14;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.blackCat.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Communication Preference',
            style: TextStyle(fontSize: _titleFs, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          // SwitchListTile needs a Material ancestor with a resolvable color
          // for its ink splashes -- the surrounding Container's BoxDecoration
          // doesn't count, so without this it throws "background color or
          // ink splashes may be invisible".
          Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: emailNotifications,
                  onChanged: onEmailChanged,
                  title: const Text(
                    'Email Notifications',
                    style: TextStyle(
                      fontSize: _labelFs,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  activeThumbColor: AppColors.blackCat,
                  activeTrackColor: AppColors.blackCat.withValues(alpha: 0.35),
                  inactiveThumbColor: AppColors.blackCatLight,
                  inactiveTrackColor: AppColors.blackCatLight.withValues(
                    alpha: 0.35,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: smsNotifications,
                  onChanged: onSmsChanged,
                  title: const Text(
                    'SMS Notifications',
                    style: TextStyle(
                      fontSize: _labelFs,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  activeThumbColor: AppColors.blackCat,
                  activeTrackColor: AppColors.blackCat.withValues(alpha: 0.35),
                  inactiveThumbColor: AppColors.blackCatLight,
                  inactiveTrackColor: AppColors.blackCatLight.withValues(
                    alpha: 0.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
