import 'package:flutter/material.dart';

import 'autocomplete_dropdown_sizing.dart';
import '../theme/app_colors.dart';

class SearchableDropdownField extends StatelessWidget {
  const SearchableDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint = 'Select',
    this.fillColor = AppColors.snow,
    this.borderColor = AppColors.blackCatBorderLight,
    this.labelStyle,
    this.textStyle,
    this.labelBottomSpacing = 6,
    this.verticalPadding = 6,
    this.fieldHeight = 46,
  });

  final String label;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final String? value;
  final String hint;
  final Color fillColor;
  final Color borderColor;
  final TextStyle? labelStyle;
  final TextStyle? textStyle;
  final double labelBottomSpacing;
  final double verticalPadding;
  final double fieldHeight;

  @override
  Widget build(BuildContext context) {
    final current = (value ?? '').trim();
    final defaultLabelStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      color: Colors.black.withOpacity(0.7),
    );
    final defaultTextStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: Colors.black.withOpacity(0.9),
    );
    final normalizedItems = items
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle ?? defaultLabelStyle),
        SizedBox(height: labelBottomSpacing),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: current),
          optionsBuilder: (textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();
            if (query.isEmpty) return const Iterable<String>.empty();
            return normalizedItems.where(
              (item) => item.toLowerCase().contains(query),
            );
          },
          onSelected: onChanged,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              textAlignVertical: TextAlignVertical.center,
              onTap: () {
                if (controller.text.trim().isEmpty &&
                    normalizedItems.isNotEmpty) {
                  controller.value = const TextEditingValue(text: ' ');
                  controller.selection = const TextSelection.collapsed(
                    offset: 1,
                  );
                  controller.value = const TextEditingValue(text: '');
                }
              },
              onSubmitted: (_) => onSubmitted(),
              onTapOutside: (_) => focusNode.unfocus(),
              style: textStyle ?? defaultTextStyle,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withOpacity(0.45),
                ),
                filled: true,
                fillColor: fillColor,
                isDense: true,
                constraints: BoxConstraints(minHeight: fieldHeight),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: verticalPadding,
                ),
                suffixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Colors.black.withOpacity(0.55),
                ),
                suffixIconConstraints: const BoxConstraints(
                  minHeight: 32,
                  minWidth: 32,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: borderColor, width: 1.2),
                ),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final list = options.toList(growable: false);
            final menuHeight = AutocompleteDropdownSizing.menuHeight(
              itemCount: list.length,
              itemExtent: 40,
            );
            return TextFieldTapRegion(
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 6,
                  color: fillColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                    side: BorderSide(color: borderColor),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: menuHeight,
                      minWidth: 220,
                    ),
                    child: list.isEmpty
                        ? const SizedBox.shrink()
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shrinkWrap: AutocompleteDropdownSizing.shrinkWrap(
                              list.length,
                            ),
                            physics: AutocompleteDropdownSizing.scrollPhysics(
                              list.length,
                            ),
                            itemCount: list.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              color: Colors.black.withOpacity(0.08),
                            ),
                            itemBuilder: (context, index) {
                              final item = list[index];
                              return InkWell(
                                onTap: () => onSelected(item),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
