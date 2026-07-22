import 'dart:async';

import 'package:flutter/material.dart';
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
//  7. Screen/route roots -> `Semantics(scopesRoute: true, namesRoute: true,
//     label: '<page purpose>')` at the top of the page, as done below.
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

class _HomePageState extends State<HomePage> {
  static const Color _blackCat = Color(0xFF292222);
  static const Color _snow = Color(0xFFFAF9F9);
  static const Color _focusRing = Color(0xFFFFBF47);

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

  @override
  void dispose() {
    _signInFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheAssets) return;
    _didPrecacheAssets = true;
    _precacheHomeAssets();
  }

  void _precacheHomeAssets() {
    final mediaQuery = MediaQuery.maybeOf(context);
    final dpr = mediaQuery?.devicePixelRatio ?? 1.0;
    final size = mediaQuery?.size ?? const Size(1080, 1920);
    final safeBgWidth = ((size.width <= 0 ? 1080 : size.width) * dpr).round();
    final safeBgHeight = ((size.height <= 0 ? 1920 : size.height) * dpr).round();
    final safeLogoWidth = (350 * (dpr <= 0 ? 1.0 : dpr)).round();

    final bgProvider = ResizeImage(
      const AssetImage('assets/images/jntlogo1.png'),
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

  ButtonStyle _signInButtonStyle() {
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
        if (states.contains(WidgetState.focused)) {
          return const BorderSide(color: _focusRing, width: 3);
        }
        return BorderSide.none;
      }),
      elevation: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return 0;
        if (states.contains(WidgetState.focused)) return 2;
        return 1;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return _focusRing.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.pressed)) {
          return _snow.withValues(alpha: 0.10);
        }
        return null;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dpr = mediaQuery.devicePixelRatio;
    final safeLogoWidth = (350 * (dpr <= 0 ? 1.0 : dpr)).round();
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
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: Image.asset(
                    'assets/images/jntlogo1.png',
                    filterQuality: FilterQuality.high,
                  ),
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
                  final logoHeight =
                      (constraints.maxHeight * 0.42).clamp(180.0, 300.0);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: Column(
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
                                    style: _signInButtonStyle(),
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
                          ),
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
