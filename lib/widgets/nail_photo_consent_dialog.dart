import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Contact address referenced in the nail-photo consent disclosure below.
/// Update here if/when a dedicated privacy inbox is set up.
const String kNailPhotoConsentPrivacyEmail = 'contactus@jntnails.com';

/// Inline consent label used next to the nail-photo consent checkbox on the
/// client and client-artist registration pages. Tapping "here" opens
/// [showNailPhotoConsentModal] with the full consent disclosure.
class NailPhotoConsentLabel extends StatefulWidget {
  const NailPhotoConsentLabel({super.key, this.fontSize = 13});

  final double fontSize;

  @override
  State<NailPhotoConsentLabel> createState() => _NailPhotoConsentLabelState();
}

class _NailPhotoConsentLabelState extends State<NailPhotoConsentLabel> {
  late final TapGestureRecognizer _linkRecognizer;

  @override
  void initState() {
    super.initState();
    _linkRecognizer = TapGestureRecognizer()
      ..onTap = () => showNailPhotoConsentModal(context);
  }

  @override
  void dispose() {
    _linkRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: widget.fontSize,
      color: AppColors.blackCat,
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          const TextSpan(
            text:
                'I consent to the collection, automated processing, and '
                'retention of my measurement photos as described ',
          ),
          TextSpan(
            text: 'here',
            recognizer: _linkRecognizer,
            style: baseStyle.copyWith(
              decoration: TextDecoration.underline,
              fontWeight: FontWeight.w700,
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

/// Shows the full measurement-photo consent disclosure that the "here" link
/// in [NailPhotoConsentLabel] points to.
Future<void> showNailPhotoConsentModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierLabel: 'Measurement photo consent',
    builder: (dialogContext) => Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Measurement photo consent',
      child: Dialog(
        backgroundColor: AppColors.snow,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Measurement Photo Consent',
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Arial',
                  ),
                ),
                const SizedBox(height: 14),
                const Flexible(
                  child: SingleChildScrollView(
                    child: _NailPhotoConsentBody(),
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

class _NailPhotoConsentBody extends StatelessWidget {
  const _NailPhotoConsentBody();

  static const _bodyStyle = TextStyle(
    color: AppColors.blackCat,
    fontSize: 13,
    fontFamily: 'Arial',
    height: 1.4,
  );
  static const _boldStyle = TextStyle(
    color: AppColors.blackCat,
    fontSize: 13,
    fontFamily: 'Arial',
    fontWeight: FontWeight.w700,
    height: 1.4,
  );

  Widget _item(String number, String lead, String rest) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          style: _bodyStyle,
          children: [
            TextSpan(text: '$number. ', style: _boldStyle),
            TextSpan(text: '$lead: ', style: _boldStyle),
            TextSpan(text: rest),
          ],
        ),
      ),
    );
  }

  Widget _subItem(String lead, List<InlineSpan> restSpans) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, bottom: 10),
      child: Text.rich(
        TextSpan(
          style: _bodyStyle,
          children: [
            const TextSpan(text: '• '),
            TextSpan(text: '$lead: ', style: _boldStyle),
            ...restSpans,
          ],
        ),
      ),
    );
  }

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
            'By checking this box, I acknowledge and agree that:',
            style: _bodyStyle,
          ),
        ),
        _item(
          '1',
          'What JNT Collects',
          'JNT will collect photos of my nails and hands that I submit '
              'through the sizing feature. These photos may include hand '
              'geometry that could be considered biometric information '
              'under certain laws (such as the Illinois Biometric '
              'Information Privacy Act).',
        ),
        _item(
          '2',
          'Purpose',
          'These photos are used solely to calculate my nail measurements '
              'so that custom press-on nail sets can be made to fit me. '
              'JNT does not use these photos for any other purpose.',
        ),
        _item(
          '3',
          'Automated Processing',
          "My photos will be processed by JNT's automated sizing system, "
              'which uses AI-assisted analysis to calculate measurements. '
              'No human reviews my photos as part of this automated '
              'process.',
        ),
        _item(
          '4',
          'Who Sees My Photos',
          "Only JNT's automated sizing system processes these photos. "
              'Artists do not receive or see my photos — they receive '
              'only the resulting measurements needed to make my set. JNT '
              'does not share my measurement photos with any third party.',
        ),
        _item(
          '5',
          'Retention Period',
          'JNT will retain my measurement photos for three (3) years from '
              'my last completed order, or until I close my account, '
              'whichever occurs first. After this period, or upon account '
              'closure, JNT will permanently delete my measurement photos '
              'within thirty (30) days.',
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text.rich(
            TextSpan(
              style: _bodyStyle,
              children: [
                TextSpan(text: '6. ', style: _boldStyle),
                TextSpan(text: 'My Rights:', style: _boldStyle),
              ],
            ),
          ),
        ),
        _subItem('Deletion on Request', [
          const TextSpan(
            text: 'I may request deletion of my measurement photos at any '
                'time by contacting ',
          ),
          _emailSpan,
          const TextSpan(
            text:
                '. JNT will delete them within thirty (30) days of a '
                'verified request.',
          ),
        ]),
        _subItem('Withdrawal of Consent', [
          const TextSpan(
            text: 'I may withdraw this consent at any time by contacting ',
          ),
          _emailSpan,
          const TextSpan(
            text:
                '. Withdrawal will trigger deletion of my measurement '
                'photos within thirty (30) days. Withdrawal will not '
                'affect the lawfulness of processing before withdrawal, '
                'but will prevent me from using the photo-based sizing '
                'feature for future orders.',
          ),
        ]),
        _subItem('Human Review', [
          const TextSpan(
            text:
                'I have the right to request human review of the '
                'automated measurement calculations by contacting ',
          ),
          _emailSpan,
          const TextSpan(text: '.'),
        ]),
      ],
    );
  }
}
