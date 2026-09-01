import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'nail_photo_consent_dialog.dart' show kNailPhotoConsentPrivacyEmail;

/// Checkbox shown on the artist/client-artist "Upload Completed Set" step
/// (designing status) asking whether finished press-on photos may be
/// published on JNT's app/social channels. Shared by both roles since they
/// both go through `showDesigningRequestSheet` in
/// `artist_accepted_request_sheet.dart`.
class FinishedPhotoPublishConsentTile extends StatelessWidget {
  const FinishedPhotoPublishConsentTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  static const _consentText =
      'I consent to the publication of photos of my completed '
      'press-on nail sets.';

  @override
  Widget build(BuildContext context) {
    // CheckboxListTile's `secondary` slot swallowed the info icon's own
    // Semantics node. Sibling placement plus explicit sort keys still
    // wasn't reliable -- CheckboxListTile builds its own internal semantics
    // subtree that keeps producing unpredictable ordering with a hand-added
    // neighbor. Hand-building both the checkbox row and the icon as fully
    // independent, explicit Semantics nodes (same pattern used for every
    // other checkbox/radio on the request pages this pass) removes that
    // uncertainty entirely instead of continuing to fight the framework
    // widget's internal merging.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            checked: value,
            label: _consentText,
            onTap: () => onChanged(!value),
            child: ExcludeSemantics(
              child: InkWell(
                onTap: () => onChanged(!value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: value,
                        onChanged: (v) => onChanged(v ?? false),
                        activeColor: AppColors.blackCat,
                        checkColor: AppColors.snow,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            _consentText,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12, right: 4),
          child: _ConsentInfoIcon(
            onActivate: () => showFinishedPhotoConsentModal(context),
          ),
        ),
      ],
    );
  }
}

/// Info icon that opens the consent modal on tap/click.
class _ConsentInfoIcon extends StatelessWidget {
  const _ConsentInfoIcon({required this.onActivate});

  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    // No MouseRegion.onEnter-triggered open here anymore -- TalkBack/
    // VoiceOver's touch-exploration scan can synthesize a pointer-enter
    // event as the accessibility cursor merely passes over this icon
    // (not an intentional activation), which was popping the modal open
    // mid-swipe and hijacking focus before the user ever perceived
    // landing on the icon itself. Tap/double-tap (below) already covers
    // both touch and desktop mouse clicks.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onActivate,
        behavior: HitTestBehavior.opaque,
        child: Semantics(
          button: true,
          label: 'More about photo publication consent',
          child: Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.blackCat.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

/// Shows the full disclosure the info icon next to
/// [FinishedPhotoPublishConsentTile] points to.
Future<void> showFinishedPhotoConsentModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierLabel: 'Photo publication consent',
    builder: (dialogContext) => Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Photo publication consent',
      child: Dialog(
        backgroundColor: AppColors.snow,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Photo Publication Consent',
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Arial',
                  ),
                ),
                const SizedBox(height: 12),
                const Flexible(
                  child: SingleChildScrollView(
                    child: _FinishedPhotoConsentBody(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    autofocus: true,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.blackCat,
                      foregroundColor: AppColors.snow,
                      elevation: 0,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Arial',
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

class _FinishedPhotoConsentBody extends StatelessWidget {
  const _FinishedPhotoConsentBody();

  // Deliberately smaller than the main registration consent dialog's body
  // text -- this one is reached from an inline info icon, not a full-page
  // registration step.
  static const _bodyStyle = TextStyle(
    color: AppColors.blackCat,
    fontSize: 11.5,
    fontFamily: 'Arial',
    height: 1.4,
  );
  static const _boldStyle = TextStyle(
    color: AppColors.blackCat,
    fontSize: 11.5,
    fontFamily: 'Arial',
    fontWeight: FontWeight.w700,
    height: 1.4,
  );
  static const _emailSpan = TextSpan(
    text: kNailPhotoConsentPrivacyEmail,
    style: _boldStyle,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'By checking this box, I agree that JNT may publish photos of '
            'my completed press-on nail sets on the JNT app and JNT '
            'social media channels (such as Instagram, TikTok, and '
            'Pinterest) to showcase artists’ work and inspire other '
            'clients. These photos show only the nails — not my hand '
            'or anything personally identifying.',
            style: _bodyStyle,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            'If I do not check this box:',
            style: _boldStyle,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 4, left: 14),
          child: Text(
            '• My order will still be processed normally.',
            style: _bodyStyle,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12, left: 14),
          child: Text(
            '• My final-product photos will not be published on '
            'JNT’s platforms.',
            style: _bodyStyle,
          ),
        ),
        Text.rich(
          TextSpan(
            style: _bodyStyle,
            children: [
              const TextSpan(text: 'Withdrawal: ', style: _boldStyle),
              const TextSpan(
                text: 'I may withdraw this consent and request removal of '
                    'any previously published photo at any time by '
                    'contacting ',
              ),
              _emailSpan,
              const TextSpan(
                text: '. JNT will remove it within thirty (30) days.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
