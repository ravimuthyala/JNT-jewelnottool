import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utlis/responsive_layout.dart';
import 'login_page.dart';

// -----------------------------------------------------------------------
// ADA / Section 508 (WCAG 2.1 AA) convention — reference implementation.
//
// This page models the pattern used across the app for accessibility work.
// It must always be invisible to non-screen-reader users: no new visible
// Text, no layout/spacing/color changes — only semantics-tree metadata.
//
// Most stock Material widgets already produce correct semantics for free
// (TextFormField with decoration.labelText, ElevatedButton with a Text
// child, a labeled Radio/Checkbox, a labeled BottomNavigationBarItem).
// Do NOT wrap those in extra Semantics — that's redundant, not required.
//
// Explicit Semantics is only needed for:
//  1. Icon-only IconButtons -> just add `tooltip:` (Flutter derives the
//     semantic label from it automatically; no ExcludeSemantics needed).
//  2. Custom tap targets: GestureDetector/InkWell wrapping a bare
//     Container/Text/Icon with no built-in semantics (cards, tiles, upload
//     controls) -> `Semantics(button: true, label: ..., onTap: ...)` around
//     `ExcludeSemantics(child: <the decorative visual subtree>)`. See
//     lib/widgets/registration_profile_upload.dart for a worked example.
//  3. Composite/custom form controls with no automatic label (e.g. a
//     hint-only TextField/TextFormField with no labelText) ->
//     `Semantics(label: '...', child: TextFormField(...))` WITHOUT
//     ExcludeSemantics. Wrapping a live editable TextField/TextFormField in
//     ExcludeSemantics is a documented Flutter bug risk (breaks real text
//     input for screen readers — see flutter/flutter#172206) and must
//     never be done, even though it's the right call for #2's decorative
//     content.
//  4. Color-only status indicators -> pair with text/icon; if truly
//     graphical-only, add `Semantics(label: ...)`.
//  5. Meaningful images/avatars -> a real label, or ExcludeSemantics if
//     purely decorative.
//  6. Dynamic content (errors, success/failure messages, loading states)
//     -> `Semantics(liveRegion: true, ...)` so changes are announced
//     without the user needing to re-explore the screen.
//  7. Screen/route roots -> `Semantics(scopesRoute: true,
//     explicitChildNodes: true, namesRoute: true, label: '<page purpose>')`
//     at the top of the page, as done below.
//  8. Section headings -> `Semantics(header: true)` merged onto the title
//     Text directly (no ExcludeSemantics needed for a simple merge).
//  9. Icon-only tap targets should meet a 44x44 (iOS) / 48x48 (Android)
//     minimum hit area; pad the hit area, not the visible icon.
// -----------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  static const Color _blackCat = Color(0xFF292222);
  static const Color _snow = Color(0xFFFAF9F9);
  static const Color _focusRing = Color(0xFFFFBF47);

  // Portrait background (phones, and tablets held upright): jntlogo2.png is
  // a 1080x1920 (9:16) crop where the model's face sits right at the very
  // top (no headroom above it to sacrifice) and the lowest fingernail tip
  // sits at ~57% of the image height -- everything below that is plain
  // dress fabric that's safe to crop away. BoxFit.cover with
  // Alignment.topCenter crops purely from the bottom, which is safe as long
  // as the screen doesn't need more than that ~43% cropped off. Beyond that,
  // fall back to BoxFit.contain instead of cropping into the face or nails.
  static const double _bgPortraitImageAspect = 1080 / 1920;
  static const double _bgPortraitContentVisibleFraction = 0.57;
  static const String _bgPortraitAsset = 'assets/images/jntlogo2.png';
  static const Alignment _bgPortraitAlignment = Alignment.topCenter;

  BoxFit _backgroundFitPortrait(Size size) {
    if (size.height <= 0) return BoxFit.cover;
    final screenAspect = size.width / size.height;
    if (screenAspect <= _bgPortraitImageAspect) return BoxFit.cover;
    final visibleFraction = _bgPortraitImageAspect / screenAspect;
    return visibleFraction >= _bgPortraitContentVisibleFraction
        ? BoxFit.cover
        : BoxFit.contain;
  }

  // Landscape background (tablets/iPad rotated to landscape, the one
  // orientation phones never reach -- see main.dart): jntlogo_tablet.png is
  // a 1586x992 (~16:10) crop composed with the hand/face content hugging the
  // right edge and the left ~33% left empty for this sign-in content.
  // - screenAspect >= imageAspect (screen wider/more panoramic than the
  //   photo, e.g. most tablets in landscape): BoxFit.cover's scale is
  //   width-bound, so it only crops top/bottom -- a small, safe crop.
  // - screenAspect < imageAspect (screen narrower than the photo, e.g. a
  //   4:3 iPad): cover's scale is height-bound, cropping left/right instead.
  //   Alignment.centerRight makes that crop come entirely from the left, an
  //   ~33% margin. Beyond that budget, fall back to BoxFit.contain -- its
  //   letterbox bars land on the left, which is exactly the reserved
  //   content zone anyway.
  static const double _bgLandscapeImageAspect = 1586 / 992;
  static const double _bgLandscapeContentVisibleFraction = 0.67;
  static const String _bgLandscapeAsset = 'assets/images/jntlogo_tablet.png';
  static const Alignment _bgLandscapeAlignment = Alignment.centerRight;

  BoxFit _backgroundFitLandscape(Size size) {
    if (size.height <= 0) return BoxFit.cover;
    final screenAspect = size.width / size.height;
    if (screenAspect >= _bgLandscapeImageAspect) return BoxFit.cover;
    final visibleFraction = screenAspect / _bgLandscapeImageAspect;
    return visibleFraction >= _bgLandscapeContentVisibleFraction
        ? BoxFit.cover
        : BoxFit.contain;
  }

  // Home also verifies the orientation policy once MediaQuery has the final
  // logical size. main.dart applies the same policy before the first frame:
  // phones are portrait-only and tablets/iPads may rotate freely.
  static const double _tabletShortestSideThreshold = 600.0;
  bool? _didAllowLandscape;

  void _applyOrientationForScreenSize(Size size) {
    final isTablet = size.shortestSide >= _tabletShortestSideThreshold;
    if (_didAllowLandscape == isTablet) return;
    _didAllowLandscape = isTablet;
    unawaited(
      SystemChrome.setPreferredOrientations(
        isTablet
            ? DeviceOrientation.values
            : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
      ),
    );
  }

  bool _didPrecacheAssets = false;
  final FocusNode _signInFocusNode = FocusNode(debugLabel: 'signInButton');
  bool _didSetInitialA11yState = false;

  bool _shouldAutoFocusForAccessibility(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.accessibleNavigation ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .accessibleNavigation;
  }

  bool _didSubscribeToRouteObserver = false;

  @override
  void initState() {
    super.initState();
    // This page manages its own full-bleed background in both orientations
    // (see the fit helpers above) rather than the app-wide tablet width cap
    // in main.dart's MaterialApp.builder, which would feed that background
    // math the wrong aspect ratio. Opt out immediately; the RouteAware
    // callbacks below keep this in sync with actual visibility afterward
    // (this page stays mounted-but-hidden, not disposed, whenever a dialog
    // or another route -- Sign In, Create Account, the registration flows
    // -- is pushed on top of it).
    fullBleedPageActive.value = true;
  }

  @override
  void dispose() {
    fullBleedPageActive.value = false;
    jntRouteObserver.unsubscribe(this);
    _signInFocusNode.dispose();
    // Do not restore portrait-only mode here. main.dart establishes the
    // device policy for the full app session: phones stay portrait-only,
    // while tablets/iPads remain free to use landscape on logged-in pages.
    // Re-locking orientation while this route is disposed causes the visible
    // full-width -> phone-width letterboxing glitch after login.
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyOrientationForScreenSize(MediaQuery.sizeOf(context));
    if (!_didSubscribeToRouteObserver) {
      final route = ModalRoute.of(context);
      if (route is PageRoute<void>) {
        _didSubscribeToRouteObserver = true;
        jntRouteObserver.subscribe(this, route);
      }
    }
    if (_didPrecacheAssets) return;
    _didPrecacheAssets = true;
    _precacheHomeAssets();
  }

  // RouteAware: fires when another route is pushed on top of this one --
  // this page is still mounted, just hidden, so initState/dispose alone
  // can't detect that. Re-enable the app-wide tablet cap for whatever's now
  // showing, and restore full-bleed once back on top.
  @override
  void didPushNext() => fullBleedPageActive.value = false;

  @override
  void didPopNext() => fullBleedPageActive.value = true;

  void _precacheHomeAssets() {
    final mediaQuery = MediaQuery.maybeOf(context);
    final dpr = mediaQuery?.devicePixelRatio ?? 1.0;
    final size = mediaQuery?.size ?? const Size(1080, 1920);
    final isLandscape = size.width > size.height;
    final safeBgWidth = ((size.width <= 0 ? 1080 : size.width) * dpr).round();
    final safeBgHeight = ((size.height <= 0 ? 1920 : size.height) * dpr)
        .round();
    final safeLogoWidth = (350 * (dpr <= 0 ? 1.0 : dpr)).round();

    final bgProvider = ResizeImage(
      AssetImage(isLandscape ? _bgLandscapeAsset : _bgPortraitAsset),
      width: safeBgWidth,
      height: safeBgHeight,
    );
    final logoProvider = ResizeImage(
      const AssetImage('assets/images/JNTWhitelogo.png'),
      width: safeLogoWidth,
    );

    unawaited(
      Future.wait([
        precacheImage(bgProvider, context),
        precacheImage(logoProvider, context),
      ]),
    );
  }

  Future<void> _openLoginPopup() async {
    debugPrint('SIGN IN ACTIVATED');

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => const LoginDialog(),
    );

    if (!mounted) return;
    _requestSignInFocusAfterSemantics();
  }

  void _requestSignInFocusAfterSemantics() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      if (_shouldAutoFocusForAccessibility(context)) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        _signInFocusNode.requestFocus();
      }
    });
  }

  // ElevatedButton gains WidgetState.focused on an ordinary tap/click, not
  // just keyboard/screen-reader navigation -- so gating purely on
  // `states.contains(WidgetState.focused)` showed the accessibility focus
  // ring to every sighted, non-ADA user the instant they tapped Sign In.
  // The ring is only meant for keyboard/switch/screen-reader users; gate it
  // on the same accessibility check _requestSignInFocusAfterSemantics
  // already uses for auto-focus.
  ButtonStyle _signInButtonStyle(BuildContext context) {
    final showFocusRing = _shouldAutoFocusForAccessibility(context);
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return const Color(0xFF100C0C);
        }
        return _blackCat;
      }),
      foregroundColor: WidgetStateProperty.all(_snow),
      minimumSize: WidgetStateProperty.all(const Size(170, 56)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      ),
      shape: WidgetStateProperty.all(
        const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      side: WidgetStateProperty.resolveWith((states) {
        if (showFocusRing && states.contains(WidgetState.focused)) {
          return const BorderSide(color: _focusRing, width: 3);
        }
        return BorderSide.none;
      }),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return 0;
        if (showFocusRing && states.contains(WidgetState.focused)) return 2;
        return 1;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (showFocusRing && states.contains(WidgetState.focused)) {
          return _focusRing.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.pressed)) {
          return _snow.withValues(alpha: 0.10);
        }
        return null;
      }),
    );
  }

  Widget _signInColumn(double logoHeight, ImageProvider logoImageProvider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            height: logoHeight,
            child: Image(
              image: logoImageProvider,
              height: 50,
              width: 350,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
        ),

        const SizedBox(height: 24),

        Semantics(
          button: true,
          label: 'Sign In',
          onTap: _openLoginPopup,
          child: ExcludeSemantics(
            child: ElevatedButton(
              style: _signInButtonStyle(context),
              onPressed: _openLoginPopup,
              focusNode: _signInFocusNode,
              autofocus: false,
              child: const Text(
                'Sign In',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Arial',
                  fontSize: 16,
                  color: _snow,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 55),

        const Text(
          'Press on. Stand out.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _snow,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dpr = mediaQuery.devicePixelRatio;
    final safeLogoWidth = (350 * (dpr <= 0 ? 1.0 : dpr)).round();
    final isLandscape = mediaQuery.size.width > mediaQuery.size.height;
    final backgroundAsset = isLandscape ? _bgLandscapeAsset : _bgPortraitAsset;
    final backgroundFit = isLandscape
        ? _backgroundFitLandscape(mediaQuery.size)
        : _backgroundFitPortrait(mediaQuery.size);
    final backgroundAlignment = isLandscape
        ? _bgLandscapeAlignment
        : _bgPortraitAlignment;
    /*final bgImageProvider = ResizeImage(
      const AssetImage('assets/images/jnt_nails.png'),
      width: ((size.width <= 0 ? 1080 : size.width) * dpr).round(),
      height: ((size.height <= 0 ? 1920 : size.height) * dpr).round(),
    );*/
    final logoImageProvider = ResizeImage(
      const AssetImage('assets/images/JNTWhitelogo.png'),
      width: safeLogoWidth,
    );

    if (!_didSetInitialA11yState) {
      _didSetInitialA11yState = true;
      _requestSignInFocusAfterSemantics();
    }

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Welcome to JNT, Jewel Not Tool. Press on. Stand out.',
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: _blackCat,
        body: Stack(
          children: [
            ExcludeSemantics(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: const Color(0xFFE6E2DE),
                child: Image.asset(
                  backgroundAsset,
                  fit: backgroundFit,
                  alignment: backgroundAlignment,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.36),
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final logoHeight = (constraints.maxHeight * 0.42).clamp(
                    180.0,
                    300.0,
                  );

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 48 : 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: _signInColumn(logoHeight, logoImageProvider),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
