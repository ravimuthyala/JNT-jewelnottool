import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../widgets/jnt_modal_app_bar.dart';
import '../services/supabase_auth_service.dart';

Future<void> showForgotPasswordModal(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.40),
    isDismissible: true,
    enableDrag: true,
    builder: (_) => const _ForgotPasswordSheet(),
  );
}

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  static const Color _alabaster = AppColors.alabaster;
  static const Color _snow = AppColors.snow;
  static const Color _focusRing = Color(0xFFFFBF47);
  static const double _fieldHeight = 46;
  static const double _fieldVerticalPadding = 14;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode(
    debugLabel: 'forgotPasswordEmail',
  );

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;

      if (!mounted) return;

      FocusScope.of(context).requestFocus(_emailFocusNode);
    });
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _shouldShowFocusRing(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return mediaQuery?.accessibleNavigation ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .accessibleNavigation;
  }

  // Typing into a field focuses it for every user, ADA or not -- gating the
  // yellow accessibility ring purely on "is this field focused" showed it
  // to sighted, non-ADA users the moment they tapped in to type their
  // email. It's only meant for keyboard/switch/screen-reader users; fall
  // back to an ordinary (non-yellow) focused border otherwise.
  InputDecoration _dec(String label, BuildContext context) {
    final focusedBorderColor = _shouldShowFocusRing(context)
        ? _focusRing
        : AppColors.blackCat;
    final focusedBorderWidth = _shouldShowFocusRing(context) ? 2.0 : 1.5;
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        fontFamily: 'Arial',
      ),
      hintStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        fontFamily: 'Arial',
      ),
      errorStyle: const TextStyle(fontSize: 11, height: 1.1),
      filled: true,
      fillColor: AppColors.snow,
      isDense: false,
      constraints: const BoxConstraints(minHeight: _fieldHeight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: _fieldVerticalPadding,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: AppColors.blackCat.withValues(alpha: 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(
          color: focusedBorderColor,
          width: focusedBorderWidth,
        ),
      ),
    );
  }

  String? _emailValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
      return 'Enter a valid email';
    }
    return null;
  }

  Future<String?> _sendResetEmail(String email) {
    return SupabaseAuthService.sendPasswordResetEmail(
      email: email,
      redirectTo: 'https://jnt-app-c3097.web.app/reset-password',
    );
  }

  Future<void> _onSend() async {
    if (_formKey.currentState?.validate() != true) {
      final error = _emailValidator(_emailCtrl.text);
      if (error != null) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          error,
          Directionality.of(context),
        );
      }
      return;
    }

    final email = _emailCtrl.text.trim();
    setState(() => _loading = true);
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Sending reset link',
      Directionality.of(context),
    );

    try {
      final simulatedLink = await _sendResetEmail(email);
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Reset link sent',
        Directionality.of(context),
      );

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => _ResetLinkSentDialog(
          email: email,
          simulatedLink: simulatedLink,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final message = 'Failed to send reset link: $e';
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        label: 'Forgot password',
        explicitChildNodes: true,
        // Matches the Login/Create account modals' width so this sheet
        // reads as the same family of dialog rather than a wider, looser
        // bottom sheet -- self-contained even outside the app-wide tablet
        // cap in main.dart, which already caps to the same width anyway.
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              decoration: const BoxDecoration(borderRadius: BorderRadius.zero),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: _alabaster,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: ExcludeSemantics(
                            child: Container(
                              height: 5,
                              width: 44,
                              decoration: BoxDecoration(
                                color: AppColors.blackCat,
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        JntModalHeaderBar(
                          onClose: () => Navigator.pop(context),
                          closeTooltip: 'Close forgot password',
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: _snow,
                    child: SafeArea(
                      top: false,
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const ExcludeSemantics(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Forgot Password',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                      fontFamily: 'Arialbold',
                                      color: AppColors.blackCat,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ExcludeSemantics(
                                child: Text(
                                  "Enter your email and we'll send you a reset link.",
                                  style: TextStyle(
                                    color: AppColors.blackCat,
                                    height: 1.25,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 14,
                                    fontFamily: 'Arial',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _emailCtrl,
                                focusNode: _emailFocusNode,
                                autofocus: true,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Arial',
                                ),
                                decoration: _dec('Email', context),
                                validator: _emailValidator,
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: 220,
                                height: 52,
                                child: ElevatedButton(
                                  style:
                                      ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.blackCat,
                                        foregroundColor: AppColors.snow,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                      ).copyWith(
                                        side: WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.focused,
                                          )) {
                                            return const BorderSide(
                                              color: _focusRing,
                                              width: 2,
                                            );
                                          }
                                          return BorderSide.none;
                                        }),
                                      ),
                                  onPressed: _loading ? null : _onSend,
                                  child: _loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.snow,
                                          ),
                                        )
                                      : const Text(
                                          'Send reset link',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            fontFamily: 'Arial',
                                            color: AppColors.snow,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: TextButton(
                                  style:
                                      TextButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: AppColors.blackCat,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                      ).copyWith(
                                        side: WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.focused,
                                          )) {
                                            return const BorderSide(
                                              color: _focusRing,
                                              width: 2,
                                            );
                                          }
                                          return BorderSide.none;
                                        }),
                                      ),
                                  onPressed: _loading
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: Text(
                                    'Back to Login',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      fontSize: 14,
                                      fontFamily: 'Arial',
                                      color: AppColors.blackCat,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                          ),
                        ),
                      ),
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

class _ResetLinkSentDialog extends StatelessWidget {
  const _ResetLinkSentDialog({required this.email, this.simulatedLink});

  final String email;

  /// TEST-ONLY: non-null while [kSimulateAuthEmailSending] is on -- no real
  /// email was sent, so the recovery link is shown directly here instead so
  /// the reset flow can still be tested end-to-end.
  final String? simulatedLink;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'Reset link sent',
      child: AlertDialog(
        backgroundColor: AppColors.snow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        title: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: AppColors.blackCat.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.zero,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.blackCat,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Reset link sent',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              simulatedLink == null
                  ? 'We sent a link to $email to reset your password.'
                  : 'Simulation mode: no email was sent. Use this link to test the reset flow for $email.',
              style: TextStyle(
                color: AppColors.blackCat,
                height: 1.25,
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
            ),
            if (simulatedLink != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                simulatedLink!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.blackCat,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: simulatedLink!),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(
                      'Copy Link',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(simulatedLink!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text(
                      'Open Link',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            height: 50,
            child: ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blackCat,
                    foregroundColor: AppColors.snow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ).copyWith(
                    side: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.focused)) {
                        return const BorderSide(
                          color: _ForgotPasswordSheetState._focusRing,
                          width: 2,
                        );
                      }
                      return BorderSide.none;
                    }),
                  ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
