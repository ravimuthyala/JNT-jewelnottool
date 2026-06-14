import 'dart:async';

import 'package:flutter/material.dart';
import 'login_page.dart';
import '../services/startup_frame_gate.dart';
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

  Future<void> _precacheHomeAssets() async {
    final mediaQuery = MediaQuery.maybeOf(context);
    final dpr = mediaQuery?.devicePixelRatio ?? 1.0;
    final size = mediaQuery?.size ?? const Size(1080, 1920);
    final safeBgWidth = ((size.width <= 0 ? 1080 : size.width) * dpr).round();
    final safeBgHeight = ((size.height <= 0 ? 1920 : size.height) * dpr).round();
    final safeLogoWidth = (350 * (dpr <= 0 ? 1.0 : dpr)).round();

    final bgProvider = ResizeImage(
      const AssetImage('assets/images/jnt_nails.png'),
      width: safeBgWidth,
      height: safeBgHeight,
    );
    final logoProvider = ResizeImage(
      const AssetImage('assets/images/JNTWhitelogo.png'),
      width: safeLogoWidth,
    );

    // Keep native splash only briefly, then continue warming assets in background.
    unawaited(
      Future.wait([
        precacheImage(bgProvider, context),
        precacheImage(logoProvider, context),
      ]),
    );

    await Future<void>.delayed(const Duration(milliseconds: 220));
    StartupFrameGate.allowFirstFrame();
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
    final size = mediaQuery.size;
    final safeBgWidth = ((size.width <= 0 ? 1080 : size.width) * dpr).round();
    final safeBgHeight = ((size.height <= 0 ? 1920 : size.height) * dpr).round();
    final safeLogoWidth = (350 * (dpr <= 0 ? 1.0 : dpr)).round();
    /*final bgImageProvider = ResizeImage(
      const AssetImage('assets/images/jnt_nails.png'),
      width: safeBgWidth,
      height: safeBgHeight,
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
              color: _blackCat,
              child: FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/images/jnt_nails.png',
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
