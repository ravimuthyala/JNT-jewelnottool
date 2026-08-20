import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

bool requestAccessibilityEnabled(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  return (media?.accessibleNavigation ?? false) ||
      dispatcher.semanticsEnabled ||
      dispatcher.accessibilityFeatures.accessibleNavigation;
}

class RequestAccessibilityOnlyAction extends StatelessWidget {
  const RequestAccessibilityOnlyAction({
    super.key,
    required this.label,
    required this.onTap,
    this.hint,
    this.onAccessibilityFocus,
    this.visualLabel,
    this.enabled = true,
    this.semanticSize = 1,
  });

  final String label;
  final String? hint;
  final VoidCallback onTap;
  final VoidCallback? onAccessibilityFocus;
  final String? visualLabel;
  final bool enabled;
  final double semanticSize;

  @override
  Widget build(BuildContext context) {
    if (!requestAccessibilityEnabled(context)) {
      return const SizedBox.shrink();
    }
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      hint: hint,
      onTap: enabled ? onTap : null,
      onDidGainAccessibilityFocus: onAccessibilityFocus,
      child: visualLabel == null
          ? SizedBox(width: semanticSize, height: semanticSize)
          : ExcludeSemantics(
              child: OutlinedButton(
                onPressed: enabled ? onTap : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: Text(visualLabel!),
              ),
            ),
    );
  }
}

/// Places accessibility and keyboard focus on a modal's Close action after
/// the route animation/announcement has settled.
///
/// Put a non-visual instance first in a Stack's children, then keep the
/// visible close icon later in paint order wrapped in ExcludeSemantics.
class RequestModalInitialClose extends StatefulWidget {
  const RequestModalInitialClose({
    super.key,
    required this.label,
    required this.onClose,
    this.semanticsKey,
  });

  final String label;
  final VoidCallback onClose;
  final GlobalKey? semanticsKey;

  @override
  State<RequestModalInitialClose> createState() =>
      _RequestModalInitialCloseState();
}

class _RequestModalInitialCloseState
    extends State<RequestModalInitialClose> {
  final GlobalKey _semanticsKey = GlobalKey();
  final FocusNode _focusNode = FocusNode(debugLabel: 'requestModalClose');
  bool _focusSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted || _focusSent) return;
      _focusNode.requestFocus();
      final renderObject =
          (widget.semanticsKey ?? _semanticsKey).currentContext?.findRenderObject();
      if (renderObject == null) return;
      _focusSent = true;
      renderObject.sendSemanticsEvent(const FocusSemanticEvent());
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Semantics(
        key: widget.semanticsKey ?? _semanticsKey,
        container: true,
        focusable: true,
        button: true,
        label: widget.label,
        hint: 'Double tap to close',
        onTap: widget.onClose,
        child: const SizedBox.square(dimension: 48),
      ),
    );
  }
}

/// Announces a status or result only when platform semantics are active.
void announceRequestAccessibilityMessage(BuildContext context, String message) {
  if (!requestAccessibilityEnabled(context) || message.trim().isEmpty) return;
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
}
