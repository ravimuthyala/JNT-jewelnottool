import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../theme/app_colors.dart';
import '../utils/registration_input_utils.dart';

/// A phone-number input with a country/dial-code picker on the left,
/// matching the look and behavior of the registration pages' phone field.
///
/// Used on profile "Personal Information" (and equivalent) edit screens so
/// the country selected at registration stays visible and editable there
/// too, instead of the phone always being shown as a plain US-formatted
/// number regardless of which country it was actually registered under.
class PhoneCountryCodeField extends StatelessWidget {
  const PhoneCountryCodeField({
    super.key,
    required this.areaCode,
    required this.onAreaCodeChanged,
    required this.controller,
    this.focusNode,
    this.height = 46,
    this.fontSize = 13,
    this.semanticLabel = 'Phone number',
  });

  final String areaCode;
  final ValueChanged<String> onAreaCodeChanged;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final double height;
  final double fontSize;
  final String semanticLabel;

  static final List<Map<String, String>> _pickerCountries = codes
      .where(
        (c) =>
            (c['code'] ?? '').isNotEmpty && (c['dial_code'] ?? '').isNotEmpty,
      )
      .map(
        (c) => <String, String>{
          'name': (c['code'] ?? '').toUpperCase(),
          'code': (c['code'] ?? '').toUpperCase(),
          'dial_code': c['dial_code'] ?? '',
        },
      )
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Localizations.override(
              context: context,
              locale: const Locale('en'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CountryCodePicker(
                  onChanged: (code) =>
                      onAreaCodeChanged(code.dialCode ?? '+1'),
                  initialSelection: areaCode == '+1' ? 'US' : areaCode,
                  favorite: const ['US', '+1', '+44', '+91'],
                  countryList: _pickerCountries,
                  showFlag: false,
                  showFlagMain: false,
                  showFlagDialog: true,
                  showCountryOnly: true,
                  hideMainText: true,
                  alignLeft: true,
                  flagWidth: 20,
                  padding: EdgeInsets.zero,
                  builder: (code) {
                    final flagUri = code?.flagUri;
                    final countryAbbr = (code?.code ?? 'US').toUpperCase();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (flagUri != null)
                          Image.asset(
                            flagUri,
                            package: 'country_code_picker',
                            width: 18,
                            height: 12,
                            fit: BoxFit.cover,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          countryAbbr,
                          style: TextStyle(
                            fontSize: fontSize,
                            color: AppColors.blackCat,
                            fontFamily: 'Arial',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            color: AppColors.blackCat.withValues(alpha: 0.2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              label: semanticLabel,
              textField: true,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(fontSize: fontSize, fontFamily: 'Arial'),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                  UsPhoneTextInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: 'Enter 10-digit phone',
                  hintStyle: TextStyle(
                    fontSize: fontSize - 1,
                    color: AppColors.blackCat.withValues(alpha: 0.35),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}
