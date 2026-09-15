import 'package:flutter/widgets.dart';

/// Below this logical shortest-side width, a screen is treated as a phone.
const double kTabletShortestSideThreshold = 600.0;

bool isTabletSize(Size size) =>
    size.shortestSide >= kTabletShortestSideThreshold;

/// Returns page padding that is identical to [phone] on phones and centers
/// the usable content within [maxContentWidth] on tablets/iPads. The page's
/// app bar and background can still span the full device width.
EdgeInsets responsivePagePadding(
  BuildContext context, {
  required EdgeInsets phone,
  double maxContentWidth = 1000.0,
  double tabletGutter = 24.0,
}) {
  final size = MediaQuery.sizeOf(context);
  if (!isTabletSize(size)) return phone;

  final centeredInset = (size.width - maxContentWidth) / 2;
  final tabletInset = centeredInset > tabletGutter
      ? centeredInset
      : tabletGutter;

  return EdgeInsets.fromLTRB(
    tabletInset > phone.left ? tabletInset : phone.left,
    phone.top,
    tabletInset > phone.right ? tabletInset : phone.right,
    phone.bottom,
  );
}

/// Legacy app-frame limit used by older builds of MaterialApp.builder.
///
/// This must remain unbounded. A finite value here causes the entire app
/// (including its header, background and bottom navigation) to snap back to
/// a phone-sized frame when route visibility callbacks update. Individual
/// pages use [responsivePagePadding] to constrain only their readable content.
const double kTabletFrameMaxWidth = double.infinity;

/// A second, wider tier for pages that have been reflowed for tablet (e.g.
/// forms using [ResponsiveFieldRow] to lay fields out two-up) -- wide enough
/// for two ~380px fields plus gap/padding. See [tabletFrameWidthOverride].
const double kTabletWideFrameMaxWidth = double.infinity;

/// Overrides [kTabletFrameMaxWidth] for the app-wide tablet cap while
/// non-null. A page that has been reflowed for tablet (wider layout, fields
/// arranged to use the width) may set this in initState and reset it in
/// dispose. Both legacy limits are now unbounded so route callbacks cannot
/// reintroduce the phone frame. This remains for source compatibility with
/// existing pages. Simpler than
/// [fullBleedPageActive]'s visibility tracking: these are plain pushed
/// PageRoutes that ARE the top of the stack whenever visible, not a page
/// that can be covered by a dialog while still mounted underneath.
final ValueNotifier<double?> tabletFrameWidthOverride = ValueNotifier<double?>(
  null,
);

/// Pages that manage their own full-bleed/tablet-aware rendering (currently
/// just HomePage) set this true while they're the current *visible* route,
/// and false whenever something else is pushed on top of them, to opt out
/// of the app-wide tablet width cap only while actually on screen. A single
/// shared flag is enough since only one such page exists today; extend to a
/// small set/enum if a second one ever needs it.
///
/// This must track visibility, not just mount state: a page stays mounted
/// (but hidden) while a dialog or another route is pushed on top of it, so
/// initState/dispose alone would leave the flag stuck on for everything
/// shown above it. Pair with [jntRouteObserver] and the [RouteAware]
/// callbacks (didPush/didPushNext/didPopNext/didPop) to track real
/// visibility -- see HomePage for the reference implementation.
final ValueNotifier<bool> fullBleedPageActive = ValueNotifier<bool>(false);

/// Registered on MaterialApp.navigatorObservers in main.dart. A page can
/// subscribe to it (RouteAware) to learn when it's covered by another
/// pushed route (didPushNext) versus back on top (didPopNext) -- signals
/// initState/dispose alone can't give you, since this page stays mounted
/// the whole time it's merely obscured underneath.
final RouteObserver<PageRoute<void>> jntRouteObserver =
    RouteObserver<PageRoute<void>>();
