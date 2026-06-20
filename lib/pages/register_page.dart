import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'client_registration_page.dart';
import 'artist_registration_page.dart';
import 'client_artist_registration_page.dart';
import 'login_page.dart';
import 'company_registration_page_v2.dart';
import '../theme/app_colors.dart';

Future<void> showRegisterModal(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Color(0xFF292222).withOpacity(0.45),
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: const SizedBox(width: 560, child: RegisterPage(isModal: true)),
    ),
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.isModal = false});

  final bool isModal;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const Color _alabaster = AppColors.alabaster;
  static const Color _blackCat = AppColors.blackCat;
  static const Color _snow = AppColors.snow;
  static const Color _linkShade = AppColors.blackCat;
  static const Color _focusRing = Color(0xFFFFBF47);
  final FocusNode _clientFocusNode = FocusNode(debugLabel: 'clientRoleTile');
  bool _didRedirectInitialA11yFocus = false;
  bool _closeSemanticsEnabled = false;

  bool get _isAdaMode =>
      WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .accessibleNavigation ||
      (MediaQuery.maybeOf(context)?.accessibleNavigation ?? false);

  void _focusClientTile() {
    FocusScope.of(context).requestFocus(_clientFocusNode);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (_isAdaMode) {
        _focusClientTile();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        if (!mounted) return;
        _focusClientTile();
        SemanticsService.announce(
          'Client. Collaborate with top artists on personalized designs.',
          Directionality.of(context),
        );
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        setState(() => _closeSemanticsEnabled = true);
      }
    });
  }

  @override
  void dispose() {
    _clientFocusNode.dispose();
    super.dispose();
  }

  bool client = false;
  bool artist = false;
  bool branding = false;

  // Client + Artist allowed together
  void toggleClient() {
    setState(() {
      client = !client;
      if (client || artist) branding = false;
    });
    SemanticsService.announce(
      client ? 'Client selected' : 'Client not selected',
      Directionality.of(context),
    );
  }

  void toggleArtist() {
    setState(() {
      artist = !artist;
      if (client || artist) branding = false;
    });
    if (artist) {
      SemanticsService.announce('Artist selected', Directionality.of(context));
    }
  }

  // Branding is exclusive
  void toggleBranding() {
    final wasBranding = branding;
    setState(() {
      branding = !branding;
      if (branding) {
        client = false;
        artist = false;
      }
    });
    if (!wasBranding && branding) {
      SemanticsService.announce(
        'Brands selected. Client and Artist cleared.',
        Directionality.of(context),
      );
    }
  }

  bool get valid => client || artist || branding;

  // ✅ Update ONLY your _continue() to keep old navigation commented,

  void _continue() {
    if (!valid) return;

    Widget page;

    // ---------------------------
    // ✅ OLD NAVIGATION (kept, commented)
    // ---------------------------
    // if (branding) {
    // } else if (client && artist) {
    //   page = const ClientArtistRegistrationPage();
    // } else if (artist) {
    //   page = const ArtistRegistrationPage();
    // } else {
    //   page = const ClientRegistrationPage();
    // }

    // ---------------------------
    // ✅ NEW NAVIGATION (active)
    // ---------------------------
    if (branding) {
      page = const CompanyRegistrationPageV2(); // ✅ new company page v2
    } else if (client && artist) {
      page = const ClientArtistRegistrationPage();
    } else if (artist) {
      page = const ArtistRegistrationPage();
    } else {
      page = const ClientRegistrationPage();
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    if (widget.isModal) {
      rootNavigator.pop();
      rootNavigator.push(MaterialPageRoute(builder: (_) => page));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      label: 'Create account',
      explicitChildNodes: true,
      child: Scaffold(
        backgroundColor: AppColors.snow,
        appBar: AppBar(
          backgroundColor: AppColors.alabaster,
          surfaceTintColor: AppColors.alabaster,
          elevation: 0,
          automaticallyImplyLeading: false,
          centerTitle: true,
          title: ExcludeSemantics(
            child: Image.asset(
              'assets/images/jnt_logo_black.png',
              height: 50,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          actions: [
            Semantics(
              sortKey: const OrdinalSortKey(99),
              onDidGainAccessibilityFocus: () {
                if (_didRedirectInitialA11yFocus || !mounted) return;
                _didRedirectInitialA11yFocus = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _focusClientTile();
                  SemanticsService.announce(
                    'Client. Collaborate with top artists on personalized designs.',
                    Directionality.of(context),
                  );
                });
              },
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                child: ExcludeSemantics(
                  excluding: !_closeSemanticsEnabled,
                  child: IconButton(
                    tooltip: 'Close create account',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    style: ButtonStyle(
                      shape: WidgetStateProperty.all(
                        const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                      side: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return const BorderSide(color: _focusRing, width: 2);
                        }
                        return BorderSide.none;
                      }),
                    ),
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      if (widget.isModal) {
                        Navigator.pop(context);
                        return;
                      }
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 22),

              // Client / Artist
              _RoleTileNoIcon(
                title: 'Client',
                subtitle:
                    'Collaborate with top artists on personalized designs.',
                selected: client,
                onTap: toggleClient,
                focusNode: _clientFocusNode,
                autofocus: _isAdaMode,
                focusRingColor: _focusRing,
                semanticSortOrder: 1,
              ),
              const SizedBox(height: 12),
              _RoleTileNoIcon(
                title: 'Artist',
                subtitle: 'Turn your craft into paid, high-value work.',
                selected: artist,
                onTap: toggleArtist,
                focusRingColor: _focusRing,
                semanticSortOrder: 2,
              ),

              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: ExcludeSemantics(
                      child: Divider(
                        thickness: 1,
                        color: AppColors.blackCat.withOpacity(0.15),
                      ),
                    ),
                  ),
                  Semantics(
                    label: 'Or',
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'OR',
                          style: TextStyle(fontWeight: FontWeight.w400),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Divider(
                        thickness: 1,
                        color: AppColors.blackCat.withOpacity(0.15),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Branding
              _RoleTileNoIcon(
                title: 'Brands',
                subtitle: 'Partnerships through campaigns and collaborations.',
                selected: branding,
                onTap: toggleBranding,
                focusRingColor: _focusRing,
                semanticSortOrder: 4,
              ),

              const SizedBox(height: 26),

              Center(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style:
                        ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blackCat,
                          foregroundColor: AppColors.snow,
                          disabledBackgroundColor: AppColors.blackCat
                              .withOpacity(0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ).copyWith(
                          side: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.focused)) {
                              return const BorderSide(
                                color: _focusRing,
                                width: 2,
                              );
                            }
                            return BorderSide.none;
                          }),
                        ),
                    onPressed: valid ? _continue : null,
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Arial',
                        color: AppColors.snow,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ExcludeSemantics(
                    child: Text(
                      'Already have an account? ',
                      style: TextStyle(fontSize: 14, fontFamily: 'Arial'),
                    ),
                  ),
                  TextButton(
                    style:
                        TextButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: _linkShade,
                          minimumSize: const Size(48, 48),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ).copyWith(
                          side: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.focused)) {
                              return const BorderSide(
                                color: _focusRing,
                                width: 2,
                              );
                            }
                            return BorderSide.none;
                          }),
                        ),
                    onPressed: () async {
                      if (widget.isModal) {
                        Navigator.pop(context);
                      } else {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      }
                      await showDialog(
                        context: Navigator.of(
                          context,
                          rootNavigator: true,
                        ).context,
                        barrierDismissible: true,
                        barrierColor: _blackCat.withOpacity(0.45),
                        builder: (_) => const LoginDialog(),
                      );
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Arial',
                        color: _linkShade,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Role tile (NO ICON, NO CHECKBOX)
/// Tap selection → color highlight only
/// ---------------------------------------------------------------------------
class _RoleTileNoIcon extends StatefulWidget {
  const _RoleTileNoIcon({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.focusNode,
    this.autofocus = false,
    required this.focusRingColor,
    this.semanticSortOrder,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color focusRingColor;
  final double? semanticSortOrder;

  @override
  State<_RoleTileNoIcon> createState() => _RoleTileNoIconState();
}

class _RoleTileNoIconState extends State<_RoleTileNoIcon> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.selected
        ? AppColors.blackCat
        : AppColors.blackCat.withOpacity(0.35);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: '${widget.title}. ${widget.subtitle}',
      value: widget.selected ? 'Selected' : 'Not selected',
      onTap: widget.onTap,
      sortKey: widget.semanticSortOrder == null
          ? null
          : OrdinalSortKey(widget.semanticSortOrder!),
      child: ExcludeSemantics(
        child: Focus(
          focusNode: widget.focusNode,
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: InkWell(
            onTap: widget.onTap,
            autofocus: widget.autofocus,
            borderRadius: BorderRadius.zero,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.snow,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: _isFocused ? widget.focusRingColor : borderColor,
                  width: _isFocused ? 2 : (widget.selected ? 1.6 : 1.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.blackCat,
                      fontFamily: 'ArialBold',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: FontWeight.w400,
                      color: AppColors.blackCat,
                      fontFamily: 'Arial',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
