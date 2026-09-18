import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/account_deactivation_service.dart';
import '../theme/app_colors.dart';

/// Deactivate-account entry point shared by every profile page (client,
/// artist, brand/company, client-artist). Checks for active orders first;
/// if any exist, shows a blocking message and returns to the caller
/// untouched. Otherwise shows a confirm dialog, deactivates on confirm,
/// signs the user out immediately, then calls [onSignedOut] so the caller
/// can reuse its own existing logout navigation instead of this widget
/// reinventing it.
Future<void> showDeactivateAccountFlow({
  required BuildContext context,
  required Future<void> Function() onSignedOut,
}) async {
  final outcome = await AccountDeactivationService.checkEligibility();
  if (!context.mounted) return;

  if (outcome is DeactivateAccountFailed) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(outcome.message)));
    return;
  }

  if (outcome is DeactivateAccountBlocked) {
    await _showActiveOrdersBlockingDialog(context, outcome.activeOrderCount);
    return;
  }

  final confirmResult = await showDialog<_ConfirmDialogResult>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ConfirmDeactivateDialog(),
  );
  if (!context.mounted || confirmResult == null) return;

  switch (confirmResult) {
    case _ConfirmDialogSucceeded():
      // Explicit sign-out for instant UX -- the realtime deactivation
      // watchdog in main.dart would eventually catch this row change too,
      // but that's a round trip we don't need to wait on here.
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {
        // Ignored -- the row is already deactivated either way, and every
        // profile page's own onSignedOut still resets navigation below.
      }
      await onSignedOut();
    case _ConfirmDialogBlocked(:final activeOrderCount):
      if (!context.mounted) return;
      await _showActiveOrdersBlockingDialog(context, activeOrderCount);
  }
}

Future<void> _showActiveOrdersBlockingDialog(
  BuildContext context,
  int activeOrderCount,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ActiveOrdersBlockingDialog(
      activeOrderCount: activeOrderCount,
    ),
  );
}

sealed class _ConfirmDialogResult {
  const _ConfirmDialogResult();
}

class _ConfirmDialogSucceeded extends _ConfirmDialogResult {
  const _ConfirmDialogSucceeded();
}

class _ConfirmDialogBlocked extends _ConfirmDialogResult {
  const _ConfirmDialogBlocked(this.activeOrderCount);
  final int activeOrderCount;
}

class _ActiveOrdersBlockingDialog extends StatefulWidget {
  const _ActiveOrdersBlockingDialog({required this.activeOrderCount});

  final int activeOrderCount;

  @override
  State<_ActiveOrdersBlockingDialog> createState() =>
      _ActiveOrdersBlockingDialogState();
}

class _ActiveOrdersBlockingDialogState
    extends State<_ActiveOrdersBlockingDialog> {
  final FocusNode _okFocusNode = FocusNode(debugLabel: 'deactivateBlockedOk');
  final GlobalKey _okSemanticsKey = GlobalKey(
    debugLabel: 'deactivateBlockedOkA11y',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_focusOkAfterDialogSettles());
    });
  }

  @override
  void dispose() {
    _okFocusNode.dispose();
    super.dispose();
  }

  Future<void> _focusOkAfterDialogSettles() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_okFocusNode);
    _okSemanticsKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    _okSemanticsKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.activeOrderCount;
    final orderWord = count == 1 ? 'order' : 'orders';
    final message =
        'You have $count active $orderWord. You can\'t deactivate your '
        'account until every order reaches a final state -- delivered, '
        'declined, cancelled, or expired.';

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Active Orders',
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                label: 'Active Orders',
                child: const ExcludeSemantics(
                  child: Text(
                    'Active Orders',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    height: 74,
                    width: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.balletSlippers,
                      border: Border.all(
                        color: AppColors.blackCat.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.local_shipping_outlined,
                      size: 34,
                      color: AppColors.blackCat.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: message,
                child: ExcludeSemantics(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.blackCat,
                      fontSize: 13,
                      height: 1.4,
                      fontFamily: 'Arial',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Semantics(
                  key: _okSemanticsKey,
                  button: true,
                  label: 'OK',
                  hint: 'Double tap to return to your profile',
                  child: ExcludeSemantics(
                    child: ElevatedButton(
                      focusNode: _okFocusNode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blackCat,
                        foregroundColor: AppColors.snow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmDeactivateDialog extends StatefulWidget {
  const _ConfirmDeactivateDialog();

  @override
  State<_ConfirmDeactivateDialog> createState() =>
      _ConfirmDeactivateDialogState();
}

class _ConfirmDeactivateDialogState extends State<_ConfirmDeactivateDialog> {
  final FocusNode _closeFocusNode = FocusNode(
    debugLabel: 'deactivateConfirmClose',
  );
  final GlobalKey _closeSemanticsKey = GlobalKey(
    debugLabel: 'deactivateConfirmCloseA11y',
  );

  bool _submitting = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_focusCloseAfterDialogSettles());
    });
  }

  @override
  void dispose() {
    _closeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _focusCloseAfterDialogSettles() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    FocusScope.of(context).requestFocus(_closeFocusNode);
    _closeSemanticsKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    _closeSemanticsKey.currentContext?.findRenderObject()?.sendSemanticsEvent(
      const FocusSemanticEvent(),
    );
  }

  void _announce(String message) {
    if (!mounted) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  Future<void> _submitDeactivate() async {
    setState(() {
      _submitting = true;
      _error = '';
    });
    final outcome = await AccountDeactivationService.confirmDeactivate();
    if (!mounted) return;

    switch (outcome) {
      case DeactivateAccountSucceeded():
        Navigator.of(context).pop(const _ConfirmDialogSucceeded());
      case DeactivateAccountBlocked(:final activeOrderCount):
        Navigator.of(context).pop(_ConfirmDialogBlocked(activeOrderCount));
      case DeactivateAccountFailed(:final message):
        setState(() {
          _submitting = false;
          _error = message;
        });
        _announce('Error. $message');
      case DeactivateAccountEligible():
        // Not a real outcome of confirmDeactivate() (p_confirm: true always
        // returns blocked/deactivated/error) -- treat defensively as a
        // transient failure rather than silently doing nothing.
        setState(() {
          _submitting = false;
          _error = 'Unable to deactivate account. Please try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Deactivate Account',
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        sortKey: const OrdinalSortKey(1),
                        header: true,
                        label: 'Deactivate Account',
                        child: const ExcludeSemantics(
                          child: Text(
                            'Deactivate Account?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      key: _closeSemanticsKey,
                      sortKey: const OrdinalSortKey(0),
                      button: true,
                      label: 'Close Deactivate Account',
                      hint: 'Double tap to keep your account and close',
                      onTap: () => Navigator.of(context).pop(),
                      child: ExcludeSemantics(
                        child: IconButton(
                          focusNode: _closeFocusNode,
                          tooltip: 'Close Deactivate Account',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                  ],
                ),
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  sortKey: const OrdinalSortKey(2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Your account will be deactivated and you\'ll be '
                        'signed out. Your data will not be erased -- only '
                        'an administrator can reactivate your account.',
                        style: const TextStyle(
                          color: AppColors.blackCat,
                          fontSize: 13,
                          height: 1.4,
                          fontFamily: 'Arial',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          label: 'Error. $_error',
                          child: ExcludeSemantics(
                            child: Text(
                              _error,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.blackCat
                                      .withValues(alpha: 0.72),
                                  foregroundColor: AppColors.snow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _submitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.blackCat,
                                  foregroundColor: AppColors.snow,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _submitting
                                    ? null
                                    : _submitDeactivate,
                                child: _submitting
                                    ? Semantics(
                                        liveRegion: true,
                                        label: 'Deactivating account',
                                        child: const ExcludeSemantics(
                                          child: SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.snow,
                                            ),
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Deactivate',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Semantics(
                  sortKey: const OrdinalSortKey(3),
                  button: true,
                  label: 'Close Deactivate Account',
                  onTap: () => Navigator.of(context).pop(),
                  onDidGainAccessibilityFocus: () {
                    unawaited(_focusCloseAfterDialogSettles());
                  },
                  child: const SizedBox(height: 1, width: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
