import 'package:flutter/widgets.dart';

class AutocompleteDropdownSizing {
  const AutocompleteDropdownSizing._();

  static const int maxVisibleItems = 4;
  static const double defaultVerticalPadding = 12;

  static double menuHeight({
    required int itemCount,
    required double itemExtent,
    int maxItems = maxVisibleItems,
    double verticalPadding = defaultVerticalPadding,
  }) {
    if (itemCount <= 0) return 0;
    final visibleItems = itemCount < maxItems ? itemCount : maxItems;
    return (visibleItems * itemExtent) + verticalPadding;
  }

  static ScrollPhysics scrollPhysics(
    int itemCount, {
    int maxItems = maxVisibleItems,
  }) {
    return itemCount > maxItems
        ? const ClampingScrollPhysics()
        : const NeverScrollableScrollPhysics();
  }

  static bool shrinkWrap(int itemCount, {int maxItems = maxVisibleItems}) {
    return itemCount <= maxItems;
  }
}
