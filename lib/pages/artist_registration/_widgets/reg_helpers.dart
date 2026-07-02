import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/autocomplete_dropdown_sizing.dart';

enum PayoutMethod { paypal, venmo, bankTransfer, applePay }

enum NailTechType { professional, student }

// ── Constants ─────────────────────────────────────────────────────────────────

const List<String> kUsStates = [
  'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado',
  'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho',
  'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine',
  'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi',
  'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey',
  'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio',
  'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina',
  'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia',
  'Washington', 'West Virginia', 'Wisconsin', 'Wyoming',
];

const List<String> kCountries = [
  'United States', 'Canada', 'United Kingdom', 'Australia', 'India',
  'Germany', 'France', 'Japan', 'Mexico', 'Brazil',
];

const List<String> kTimeZones = [
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
];

const List<String> kProYearsOptions = [
  '0–1 years (Beginner)',
  '1–3 years (Intermediate)',
  '3–5 years (Skilled)',
  '5–10 years (Advanced)',
  '10+ years (Expert)',
];

const List<String> kPracticeDurations = [
  '< 3 months',
  '3–6 months',
  '6–12 months',
  '1–2 years',
  '2+ years',
];

// ── Shared styling constants ───────────────────────────────────────────────────

const double kInputFs = 13;
const double kLabelFs = 16;
const double kHintFs = 12.5;
const double kFieldHeight = 46;
const double kFieldVertPad = 14;

// ── InputDecoration factory ───────────────────────────────────────────────────

InputDecoration regDec(String label, String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    hintStyle: TextStyle(
      fontSize: kHintFs,
      color: AppColors.blackCat.withValues(alpha: 0.35),
    ),
    labelStyle: TextStyle(fontSize: kLabelFs, color: AppColors.blackCat),
    errorStyle: const TextStyle(fontSize: 10.5, height: 1.1, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: AppColors.snow,
    suffixIcon: suffixIcon,
    isDense: false,
    constraints: const BoxConstraints(minHeight: kFieldHeight),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: kFieldVertPad),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColors.blackCat.withValues(alpha: 0.35)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColors.blackCat.withValues(alpha: 0.35)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: AppColors.blackCat.withValues(alpha: 0.35), width: 1.4),
    ),
  );
}

// ── Section card ──────────────────────────────────────────────────────────────

Widget regSectionCard({
  required String title,
  String? subtitle,
  required Widget child,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
    decoration: BoxDecoration(
      color: AppColors.snow,
      borderRadius: BorderRadius.zero,
      border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFamily: 'ArialBold',
            color: AppColors.blackCat,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.blackCat,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

// ── Chip ──────────────────────────────────────────────────────────────────────

Widget regChip(String label, bool selected, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.zero,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.blackCat.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: selected
              ? AppColors.blackCat
              : AppColors.blackCat.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.check, size: 16, color: AppColors.blackCat),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: kInputFs, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

// ── Required / optional field labels ─────────────────────────────────────────

Widget regRequiredLabel(String text) {
  return Text.rich(
    TextSpan(
      text: text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.blackCat),
      children: const [
        TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
      ],
    ),
  );
}

// ── Check row (checkbox + label) ──────────────────────────────────────────────

Widget regCheckRow({
  required bool value,
  required String text,
  required ValueChanged<bool> onChanged,
}) {
  return InkWell(
    onTap: () => onChanged(!value),
    borderRadius: BorderRadius.zero,
    overlayColor: WidgetStateColor.resolveWith((_) => AppColors.blackCat.withValues(alpha: 0.12)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.blackCat,
            checkColor: AppColors.snow,
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.blackCat,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── TypeAhead picker ──────────────────────────────────────────────────────────

class RegTypeAheadField extends StatelessWidget {
  const RegTypeAheadField({
    super.key,
    required this.label,
    required this.hint,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String hint;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  String? _firstExactMatch(String input) {
    final needle = input.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final option in options) {
      if (option.trim().toLowerCase() == needle) return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: selectedValue,
      validator: validator,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<String>(
              initialValue: TextEditingValue(text: field.value ?? ''),
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) return const Iterable<String>.empty();
                return options.where((o) => o.toLowerCase().contains(query));
              },
              onSelected: (value) {
                field.didChange(value);
                onChanged(value);
              },
              fieldViewBuilder: (ctx, textController, focusNode, onSubmitted) {
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  style: const TextStyle(fontSize: kInputFs, color: AppColors.blackCat),
                  decoration: regDec(label, hint).copyWith(fillColor: AppColors.snow),
                  onTapOutside: (_) => focusNode.unfocus(),
                  onChanged: (value) {
                    final match = _firstExactMatch(value);
                    field.didChange(match);
                    onChanged(match);
                  },
                );
              },
              optionsViewBuilder: (ctx, onSelected, optionsList) {
                final maxW = MediaQuery.of(ctx).size.width - 48;
                final count = optionsList.length;
                final menuH = AutocompleteDropdownSizing.menuHeight(itemCount: count, itemExtent: 40);
                return TextFieldTapRegion(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: AppColors.snow,
                      elevation: 4,
                      borderRadius: BorderRadius.zero,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: menuH,
                          maxWidth: maxW < 260 ? 260 : maxW,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: AutocompleteDropdownSizing.shrinkWrap(count),
                          physics: AutocompleteDropdownSizing.scrollPhysics(count),
                          itemCount: count,
                          itemBuilder: (ctx, i) {
                            final option = optionsList.elementAt(i);
                            return ListTile(
                              dense: true,
                              title: Text(
                                option,
                                style: const TextStyle(fontSize: kInputFs, color: AppColors.blackCat),
                              ),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (field.hasError) ...[
              const SizedBox(height: 4),
              Text(
                field.errorText ?? '',
                style: const TextStyle(fontSize: 10.5, color: Colors.red),
              ),
            ],
          ],
        );
      },
    );
  }
}
