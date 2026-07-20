import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'client_registration_page.dart';
// ignore: unused_import — keep for easy revert to ArtistRegistrationPage
import 'artist_registration_page.dart';
import 'artist_registration/artist_registration_flow.dart';
import 'client_artist_registration_page.dart';
import 'login_page.dart';
import 'brand_registration_page.dart';
import '../theme/app_colors.dart';
import '../widgets/jnt_modal_app_bar.dart';

Future<void> showRegisterModal(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Color(0xFF292222).withValues(alpha: 0.45),
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
  static const Color _blackCat = AppColors.blackCat;
  static const Color _linkShade = AppColors.blackCat;
  static const Color _focusRing = Color(0xFFFFBF47);

  @override
  void dispose() {
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
    SemanticsService.sendAnnouncement(
      View.of(context),
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
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Artist selected',
        Directionality.of(context),
      );
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
      SemanticsService.sendAnnouncement(
        View.of(context),
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
      page = const ArtistRegistrationFlow(); // v2 multi-step (swap back to ArtistRegistrationPage to revert)
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
        appBar: JntModalAppBar(
          onClose: () {
            if (widget.isModal) {
              Navigator.pop(context);
              return;
            }
            Navigator.of(
              context,
              rootNavigator: true,
            ).pushNamedAndRemoveUntil('/', (route) => false);
          },
          closeTooltip: 'Close registration dialog',
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
                        color: AppColors.blackCat.withValues(alpha: 0.15),
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
                        color: AppColors.blackCat.withValues(alpha: 0.15),
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
                              .withValues(alpha: 0.35),
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
                  Semantics(
                    label: 'Already have an account?',
                    child: const ExcludeSemantics(
                      child: Text(
                        'Already have an account? ',
                        style: TextStyle(fontSize: 14, fontFamily: 'Arial'),
                      ),
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
                        barrierColor: _blackCat.withValues(alpha: 0.45),
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
    required this.focusRingColor,
    this.semanticSortOrder,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
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
        : AppColors.blackCat.withValues(alpha: 0.35);

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
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: InkWell(
            onTap: widget.onTap,
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
