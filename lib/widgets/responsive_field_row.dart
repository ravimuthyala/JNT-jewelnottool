import 'package:flutter/widgets.dart';

/// Below this width, [ResponsiveFieldRow] falls back to stacking its fields
/// vertically -- the exact layout every call site already used before this
/// widget existed. Deliberately independent of the app-wide tablet
/// detection (`isTabletSize`/`kTabletShortestSideThreshold` in
/// responsive_layout.dart): this widget reacts only to the width it's
/// actually given, so it behaves correctly regardless of what container
/// ends up hosting it.
const double _kFieldRowThreshold = 500.0;

/// Lays out 1-2 form fields side by side when there's enough width for it,
/// falling back to the same stacked-column layout the call site used to
/// build inline otherwise. On narrow/phone widths this produces the exact
/// same widget structure as before (a Column with [gap] between fields),
/// so it's a phone-safe drop-in replacement for hand-stacked field pairs.
class ResponsiveFieldRow extends StatelessWidget {
  const ResponsiveFieldRow({
    super.key,
    required this.fields,
    required this.gap,
    double? runGap,
  }) : runGap = runGap ?? gap,
       assert(fields.length >= 1 && fields.length <= 2);

  final List<Widget> fields;

  /// Vertical gap between fields when stacked (narrow/phone layout).
  final double gap;

  /// Horizontal gap between fields when placed side by side (wide layout).
  /// Defaults to [gap].
  final double runGap;

  @override
  Widget build(BuildContext context) {
    if (fields.length == 1) return fields.single;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _kFieldRowThreshold) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields[0]),
              SizedBox(width: runGap),
              Expanded(child: fields[1]),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [fields[0], SizedBox(height: gap), fields[1]],
        );
      },
    );
  }
}
