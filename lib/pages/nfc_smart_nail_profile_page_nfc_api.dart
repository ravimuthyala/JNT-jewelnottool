// lib/pages/nfc_smart_nail_profile_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../theme/app_colors.dart';

class NfcSmartNailProfilePage extends StatefulWidget {
  const NfcSmartNailProfilePage({super.key});

  @override
  State<NfcSmartNailProfilePage> createState() =>
      _NfcSmartNailProfilePageState();
}

class _NfcSmartNailProfilePageState extends State<NfcSmartNailProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final Map<String, TextEditingController> _controllers = {
    'instagram': TextEditingController(),
    'tiktok': TextEditingController(),
    'snapchat': TextEditingController(),
    'facebook': TextEditingController(),
    'linkedin': TextEditingController(),
    'youtube': TextEditingController(),
    'pinterest': TextEditingController(),
    'xTwitter': TextEditingController(),
    'threads': TextEditingController(),
    'contactName': TextEditingController(),
    'contactPhone': TextEditingController(),
    'contactEmail': TextEditingController(),
    'contactWebsite': TextEditingController(),
    'emergencyContactName': TextEditingController(),
    'emergencyContactPhone': TextEditingController(),
    'website': TextEditingController(),
    'website2': TextEditingController(),
    'website3': TextEditingController(),
    'cashApp': TextEditingController(),
    'venmo': TextEditingController(),
    'paypal': TextEditingController(),
    'applePay': TextEditingController(),
    'zelle': TextEditingController(),
    'spotify': TextEditingController(),
    'appleMusic': TextEditingController(),
    'amazonMusic': TextEditingController(),
    'soundCloud': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = FirebaseFirestore.instance;
    final clientRef = db.collection('client').doc(uid);
    final clientSnap = await clientRef.get();
    final targetRef = clientSnap.exists
        ? clientRef
        : db.collection('client_artist').doc(uid);
    final snap = await targetRef.get();
    final data = snap.data()?['nfcSmartNailProfile'] as Map<String, dynamic>?;
    if (!mounted || data == null) return;

    for (final entry in _controllers.entries) {
      entry.value.text = (data[entry.key] ?? '').toString();
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Missing signed-in user.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        for (final entry in _controllers.entries)
          entry.key: entry.value.text.trim(),
        'isActivated': false,
        'activeItemType': null,
        'activeItemValue': null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final db = FirebaseFirestore.instance;
      final clientRef = db.collection('client').doc(uid);
      final clientSnap = await clientRef.get();
      final targetRef = clientSnap.exists
          ? clientRef
          : db.collection('client_artist').doc(uid);

      await targetRef.set({
        'nfcSmartNailProfile': payload,
        'client': {'nfcSmartNailProfile': payload},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NfcSavedItemsPage(profile: _currentPayload()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save NFC profile: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, String> _currentPayload() => {
    for (final entry in _controllers.entries)
      entry.key: entry.value.text.trim(),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'NFC SMART NAIL',
          style: TextStyle(
            color: AppColors.blackCat,
            fontWeight: FontWeight.w700,
            fontFamily: 'Arialbold',
            fontSize: 16,
            letterSpacing: 0.4,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.blackCat,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
          children: [
            _StatusCard(isActivated: false),
            const SizedBox(height: 20),
            _SectionTitle('Social Links'),
            _IconTextField(
              controller: _controllers['instagram']!,
              icon: _BrandIcon.instagram,
              hint: 'Instagram username or link',
            ),
            _IconTextField(
              controller: _controllers['tiktok']!,
              icon: _BrandIcon.tiktok,
              hint: 'TikTok username or link',
            ),
            _IconTextField(
              controller: _controllers['snapchat']!,
              icon: _BrandIcon.snapchat,
              hint: 'Snapchat username or link',
            ),
            _IconTextField(
              controller: _controllers['facebook']!,
              icon: _BrandIcon.facebook,
              hint: 'Facebook username or link',
            ),
            _IconTextField(
              controller: _controllers['linkedin']!,
              icon: _BrandIcon.linkedin,
              hint: 'LinkedIn username or link',
            ),
            _IconTextField(
              controller: _controllers['youtube']!,
              icon: _BrandIcon.youtube,
              hint: 'YouTube username or link',
            ),
            _IconTextField(
              controller: _controllers['pinterest']!,
              icon: _BrandIcon.pinterest,
              hint: 'Pinterest username or link',
            ),
            _IconTextField(
              controller: _controllers['xTwitter']!,
              icon: _BrandIcon.xTwitter,
              hint: 'X username or link',
            ),
            _IconTextField(
              controller: _controllers['threads']!,
              icon: _BrandIcon.threads,
              hint: 'Threads username or link',
            ),

            const SizedBox(height: 16),
            _SectionTitle('Contact Information'),
            _IconTextField(
              controller: _controllers['contactName']!,
              materialIcon: Icons.person_outline,
              hint: 'Name',
            ),
            _IconTextField(
              controller: _controllers['contactPhone']!,
              materialIcon: Icons.phone_outlined,
              hint: 'Phone',
              keyboardType: TextInputType.phone,
            ),
            _IconTextField(
              controller: _controllers['contactEmail']!,
              materialIcon: Icons.email_outlined,
              hint: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            _IconTextField(
              controller: _controllers['contactWebsite']!,
              materialIcon: Icons.language_rounded,
              hint: 'Website',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            _IconTextField(
              controller: _controllers['emergencyContactName']!,
              materialIcon: Icons.health_and_safety_outlined,
              hint: 'Emergency contact name',
            ),
            _IconTextField(
              controller: _controllers['emergencyContactPhone']!,
              materialIcon: Icons.phone_outlined,
              hint: 'Emergency contact phone',
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 16),
            _SectionTitle('Website'),
            _IconTextField(
              controller: _controllers['website']!,
              materialIcon: Icons.language_rounded,
              hint: 'Website URL',
              keyboardType: TextInputType.url,
            ),
            _IconTextField(
              controller: _controllers['website2']!,
              materialIcon: Icons.language_rounded,
              hint: 'Website URL 2',
              keyboardType: TextInputType.url,
            ),
            _IconTextField(
              controller: _controllers['website3']!,
              materialIcon: Icons.language_rounded,
              hint: 'Website URL 3',
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 16),
            _SectionTitle('Payment Links'),
            _IconTextField(
              controller: _controllers['cashApp']!,
              icon: _BrandIcon.cashApp,
              hint: 'CashApp cashtag',
            ),
            _IconTextField(
              controller: _controllers['venmo']!,
              icon: _BrandIcon.venmo,
              hint: 'Venmo username',
            ),
            _IconTextField(
              controller: _controllers['paypal']!,
              icon: _BrandIcon.paypal,
              hint: 'PayPal link or email',
            ),
            _IconTextField(
              controller: _controllers['applePay']!,
              icon: _BrandIcon.applePay,
              hint: 'Apple Pay phone or email',
            ),
            _IconTextField(
              controller: _controllers['zelle']!,
              icon: _BrandIcon.zelle,
              hint: 'Zelle phone or email',
            ),

            const SizedBox(height: 16),
            _SectionTitle('Music (Optional)'),
            _IconTextField(
              controller: _controllers['spotify']!,
              icon: _BrandIcon.spotify,
              hint: 'Spotify playlist or artist link',
            ),
            _IconTextField(
              controller: _controllers['appleMusic']!,
              icon: _BrandIcon.appleMusic,
              hint: 'Apple Music link',
            ),
            _IconTextField(
              controller: _controllers['amazonMusic']!,
              icon: _BrandIcon.amazonMusic,
              hint: 'Amazon Music link',
            ),
            _IconTextField(
              controller: _controllers['soundCloud']!,
              icon: _BrandIcon.soundCloud,
              hint: 'SoundCloud link',
            ),

            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveProfile,
                icon: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.snow,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 20),
                label: Text(_saving ? 'Saving...' : 'Save Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  disabledBackgroundColor: AppColors.blackCat.withOpacity(0.55),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Arial',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Your information is private and secure. Only the activated item will be shared when someone taps your nail.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.blackCat.withOpacity(0.65),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NfcSavedItemsPage extends StatefulWidget {
  const NfcSavedItemsPage({super.key, required this.profile});

  final Map<String, String> profile;

  @override
  State<NfcSavedItemsPage> createState() => _NfcSavedItemsPageState();
}

class _NfcSavedItemsPageState extends State<NfcSavedItemsPage> {
  _SavedNfcItem? _selectedItem;
  final bool _activating = false;

  List<_SavedNfcSection> get _sections {
    String value(String key) => (widget.profile[key] ?? '').trim();

    _SavedNfcItem? item({
      required String key,
      required String title,
      required String value,
      required IconData icon,
      required String section,
    }) {
      if (value.trim().isEmpty) return null;
      return _SavedNfcItem(
        key: key,
        title: title,
        value: value.trim(),
        icon: icon,
        section: section,
      );
    }

    _SavedNfcSection section(String title, List<_SavedNfcItem?> rawItems) {
      return _SavedNfcSection(
        title: title,
        items: rawItems.whereType<_SavedNfcItem>().toList(),
      );
    }

    return [
      section('Social Links', [
        item(
          key: 'instagram',
          title: 'Instagram',
          value: value('instagram'),
          icon: Icons.camera_alt_outlined,
          section: 'Social Links',
        ),
        item(
          key: 'tiktok',
          title: 'TikTok',
          value: value('tiktok'),
          icon: Icons.music_note_outlined,
          section: 'Social Links',
        ),
        item(
          key: 'snapchat',
          title: 'Snapchat',
          value: value('snapchat'),
          icon: Icons.chat_bubble_outline,
          section: 'Social Links',
        ),
        item(
          key: 'facebook',
          title: 'Facebook',
          value: value('facebook'),
          icon: Icons.facebook_outlined,
          section: 'Social Links',
        ),
        item(
          key: 'linkedin',
          title: 'LinkedIn',
          value: value('linkedin'),
          icon: Icons.business_center_outlined,
          section: 'Social Links',
        ),
        item(
          key: 'youtube',
          title: 'YouTube',
          value: value('youtube'),
          icon: Icons.play_circle_outline,
          section: 'Social Links',
        ),
        item(
          key: 'pinterest',
          title: 'Pinterest',
          value: value('pinterest'),
          icon: Icons.push_pin_outlined,
          section: 'Social Links',
        ),
        item(
          key: 'xTwitter',
          title: 'X',
          value: value('xTwitter'),
          icon: Icons.alternate_email_rounded,
          section: 'Social Links',
        ),
        item(
          key: 'threads',
          title: 'Threads',
          value: value('threads'),
          icon: Icons.tag,
          section: 'Social Links',
        ),
      ]),
      section('Contact Information', [
        _contactCardItem(),
        _emergencyContactItem(),
      ]),
      section('Website', [
        item(
          key: 'website',
          title: 'Website 1',
          value: value('website'),
          icon: Icons.language_rounded,
          section: 'Website',
        ),
        item(
          key: 'website2',
          title: 'Website 2',
          value: value('website2'),
          icon: Icons.language_rounded,
          section: 'Website',
        ),
        item(
          key: 'website3',
          title: 'Website 3',
          value: value('website3'),
          icon: Icons.language_rounded,
          section: 'Website',
        ),
      ]),
      section('Payment Links', [
        item(
          key: 'cashApp',
          title: 'CashApp',
          value: value('cashApp'),
          icon: Icons.attach_money_rounded,
          section: 'Payment Links',
        ),
        item(
          key: 'venmo',
          title: 'Venmo',
          value: value('venmo'),
          icon: Icons.payments_outlined,
          section: 'Payment Links',
        ),
        item(
          key: 'paypal',
          title: 'PayPal',
          value: value('paypal'),
          icon: Icons.account_balance_wallet_outlined,
          section: 'Payment Links',
        ),
        item(
          key: 'applePay',
          title: 'Apple Pay',
          value: value('applePay'),
          icon: Icons.phone_iphone_rounded,
          section: 'Payment Links',
        ),
        item(
          key: 'zelle',
          title: 'Zelle',
          value: value('zelle'),
          icon: Icons.account_balance_outlined,
          section: 'Payment Links',
        ),
      ]),
      section('Music', [
        item(
          key: 'spotify',
          title: 'Spotify',
          value: value('spotify'),
          icon: Icons.library_music_outlined,
          section: 'Music',
        ),
        item(
          key: 'appleMusic',
          title: 'Apple Music',
          value: value('appleMusic'),
          icon: Icons.music_note_outlined,
          section: 'Music',
        ),
        item(
          key: 'amazonMusic',
          title: 'Amazon Music',
          value: value('amazonMusic'),
          icon: Icons.headphones_outlined,
          section: 'Music',
        ),
        item(
          key: 'soundCloud',
          title: 'SoundCloud',
          value: value('soundCloud'),
          icon: Icons.cloud_outlined,
          section: 'Music',
        ),
      ]),
    ].where((section) => section.items.isNotEmpty).toList();
  }

  _SavedNfcItem? _contactCardItem() {
    final name = (widget.profile['contactName'] ?? '').trim();
    final phone = (widget.profile['contactPhone'] ?? '').trim();
    final email = (widget.profile['contactEmail'] ?? '').trim();
    final website = (widget.profile['contactWebsite'] ?? '').trim();
    final parts = [
      name,
      phone,
      email,
      website,
    ].where((v) => v.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return _SavedNfcItem(
      key: 'contactCard',
      title: 'Contact Card',
      value: parts.join('\n'),
      icon: Icons.contact_page_outlined,
      section: 'Contact Information',
    );
  }

  _SavedNfcItem? _emergencyContactItem() {
    final name = (widget.profile['emergencyContactName'] ?? '').trim();
    final phone = (widget.profile['emergencyContactPhone'] ?? '').trim();
    final parts = [name, phone].where((v) => v.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return _SavedNfcItem(
      key: 'emergencyContact',
      title: 'Emergency Contact',
      value: parts.join('\n'),
      icon: Icons.health_and_safety_outlined,
      section: 'Contact Information',
    );
  }

  void _activateSelectedItem() {
    final selected = _selectedItem;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select one saved item to activate.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NfcScanActivationPage(selectedItem: selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ACTIVATE NFC NAIL',
          style: TextStyle(
            color: AppColors.blackCat,
            fontWeight: FontWeight.w700,
            fontFamily: 'Arialbold',
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.blackCat,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: sections.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No saved NFC items found. Go back and enter at least one field before activation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                    children: [
                      _ActivationIntroCard(selectedItem: _selectedItem),
                      const SizedBox(height: 18),
                      for (final section in sections) ...[
                        _SectionTitle(section.title),
                        ...section.items.map(
                          (item) => _SavedItemTile(
                            item: item,
                            selected: _selectedItem?.key == item.key,
                            onTap: () => setState(() => _selectedItem = item),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      height: 52,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _activating ? null : _activateSelectedItem,
                        icon: _activating
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.snow,
                                ),
                              )
                            : const Icon(Icons.nfc_rounded, size: 20),
                        label: Text(
                          _activating
                              ? 'Opening Scanner...'
                              : 'Activate NFC Nail',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blackCat,
                          foregroundColor: AppColors.snow,
                          disabledBackgroundColor: AppColors.blackCat
                              .withOpacity(0.55),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Arial',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class NfcScanActivationPage extends StatefulWidget {
  const NfcScanActivationPage({super.key, required this.selectedItem});

  final _SavedNfcItem selectedItem;

  @override
  State<NfcScanActivationPage> createState() => _NfcScanActivationPageState();
}

class _NfcScanActivationPageState extends State<NfcScanActivationPage> {
  bool _isScanning = false;
  bool _isActivated = false;
  String? _statusMessage;

  Future<void> _startNfcScanAndActivate() async {
    if (_isScanning || _isActivated) return;

    final isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NFC is not available on this device.'),
        ),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Hold your NFC nail near your phone.';
    });

    await NfcManager.instance.startSession(
      pollingOptions: const {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      alertMessage: 'Hold your NFC nail near the top of your phone.',
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            await NfcManager.instance.stopSession(
              errorMessage: 'This NFC tag does not support NDEF.',
            );
            if (mounted) {
              setState(() {
                _isScanning = false;
                _statusMessage = 'This NFC tag does not support NDEF.';
              });
            }
            return;
          }

          if (!ndef.isWritable) {
            await NfcManager.instance.stopSession(
              errorMessage: 'This NFC tag is not writable.',
            );
            if (mounted) {
              setState(() {
                _isScanning = false;
                _statusMessage = 'This NFC tag is not writable.';
              });
            }
            return;
          }

          final payload = _buildNfcPayload(widget.selectedItem);
          final message = NdefMessage([_buildNdefRecord(payload)]);

          await ndef.write(message);
          await _persistActivation(payload: payload);

          await NfcManager.instance.stopSession(
            alertMessage: 'NFC nail activated successfully.',
          );

          if (!mounted) return;
          setState(() {
            _isScanning = false;
            _isActivated = true;
            _statusMessage = 'Activated successfully.';
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.selectedItem.title} activated successfully.'),
            ),
          );
        } catch (e) {
          await NfcManager.instance.stopSession(
            errorMessage: 'Failed to activate NFC nail.',
          );
          if (!mounted) return;
          setState(() {
            _isScanning = false;
            _statusMessage = 'Failed to activate NFC nail: $e';
          });
        }
      },
    );
  }

  NdefRecord _buildNdefRecord(String payload) {
    final uri = Uri.tryParse(payload);
    if (uri != null && uri.hasScheme) {
      return NdefRecord.createUri(uri);
    }
    return NdefRecord.createText(payload);
  }

  String _buildNfcPayload(_SavedNfcItem item) {
    final rawValue = item.value.trim();
    final normalized = rawValue.replaceAll('\n', ' ').trim();

    switch (item.key) {
      case 'instagram':
        return _socialUrl('https://instagram.com/', normalized);
      case 'tiktok':
        return _socialUrl('https://www.tiktok.com/@', normalized);
      case 'snapchat':
        return _socialUrl('https://www.snapchat.com/add/', normalized);
      case 'facebook':
        return _urlOrFallback(normalized, 'https://www.facebook.com/$normalized');
      case 'linkedin':
        return _urlOrFallback(normalized, 'https://www.linkedin.com/in/$normalized');
      case 'youtube':
        return _urlOrFallback(normalized, 'https://www.youtube.com/@$normalized');
      case 'pinterest':
        return _urlOrFallback(normalized, 'https://www.pinterest.com/$normalized');
      case 'xTwitter':
        return _socialUrl('https://x.com/', normalized);
      case 'threads':
        return _socialUrl('https://www.threads.net/@', normalized);
      case 'website':
      case 'website2':
      case 'website3':
      case 'spotify':
      case 'appleMusic':
      case 'amazonMusic':
      case 'soundCloud':
      case 'paypal':
        return _ensureUrl(normalized);
      case 'contactCard':
        return _buildContactText('Contact Card', rawValue);
      case 'emergencyContact':
        return _buildContactText('Emergency Contact', rawValue);
      default:
        return normalized;
    }
  }

  String _socialUrl(String base, String value) {
    return _urlOrFallback(value, '$base${_stripAt(value)}');
  }

  String _urlOrFallback(String value, String fallback) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    return fallback;
  }

  String _ensureUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return value;
    if (value.contains('.') && !value.contains(' ')) return 'https://$value';
    return value;
  }

  String _stripAt(String value) {
    var clean = value.trim();
    while (clean.startsWith('@')) {
      clean = clean.substring(1);
    }
    return Uri.encodeComponent(clean);
  }

  String _buildContactText(String title, String value) {
    return '$title\n$value';
  }

  Future<void> _persistActivation({required String payload}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('Missing signed-in user.');
    }

    final db = FirebaseFirestore.instance;
    final clientRef = db.collection('client').doc(uid);
    final clientSnap = await clientRef.get();
    final targetRef = clientSnap.exists
        ? clientRef
        : db.collection('client_artist').doc(uid);

    final activationPayload = {
      'isActivated': true,
      'activeItemKey': widget.selectedItem.key,
      'activeItemType': widget.selectedItem.title,
      'activeItemSection': widget.selectedItem.section,
      'activeItemValue': widget.selectedItem.value,
      'nfcWrittenPayload': payload,
      'activatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await targetRef.set({
      'nfcSmartNailProfile': activationPayload,
      'client': {'nfcSmartNailProfile': activationPayload},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _statusMessage ??
        (_isScanning
            ? 'Keep your NFC nail near your phone.'
            : 'Hold your NFC nail near the top of your phone to activate it.');

    return Scaffold(
      backgroundColor: AppColors.snow,
      appBar: AppBar(
        backgroundColor: AppColors.alabaster,
        surfaceTintColor: AppColors.alabaster,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'SCAN NFC NAIL',
          style: TextStyle(
            color: AppColors.blackCat,
            fontWeight: FontWeight.w700,
            fontFamily: 'Arialbold',
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.blackCat,
          onPressed: () async {
            if (_isScanning) {
              await NfcManager.instance.stopSession(errorMessage: 'Cancelled');
            }
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.snow,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: AppColors.blackCat.withOpacity(0.18)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.balletSlippers.withOpacity(0.45),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Icon(
                      _isActivated ? Icons.check_rounded : Icons.nfc_rounded,
                      color: AppColors.blackCat,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isActivated
                        ? 'Activated Successfully'
                        : (_isScanning ? 'Scanning...' : 'Ready to Scan'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.blackCat,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Arialbold',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.blackCat.withOpacity(0.70),
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SelectedScanItemCard(item: widget.selectedItem),
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isActivated ? () => Navigator.pop(context) : _startNfcScanAndActivate,
                icon: _isScanning
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.snow,
                        ),
                      )
                    : Icon(_isActivated ? Icons.done_rounded : Icons.sensors_rounded, size: 20),
                label: Text(
                  _isActivated
                      ? 'Done'
                      : (_isScanning ? 'Scanning...' : 'Start NFC Scan'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.blackCat,
                  foregroundColor: AppColors.snow,
                  disabledBackgroundColor: AppColors.blackCat.withOpacity(0.55),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Arial',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedNfcSection {
  const _SavedNfcSection({required this.title, required this.items});
  final String title;
  final List<_SavedNfcItem> items;
}

class _SavedNfcItem {
  const _SavedNfcItem({
    required this.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.section,
  });

  final String key;
  final String title;
  final String value;
  final IconData icon;
  final String section;
}

class _ActivationIntroCard extends StatelessWidget {
  const _ActivationIntroCard({required this.selectedItem});

  final _SavedNfcItem? selectedItem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.balletSlippers.withOpacity(0.45),
              borderRadius: BorderRadius.zero,
            ),
            child: const Icon(
              Icons.touch_app_outlined,
              color: AppColors.blackCat,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select one saved item',
                  style: TextStyle(
                    color: AppColors.blackCat,
                    fontFamily: 'Arialbold',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedItem == null
                      ? 'Only one option can be activated per NFC chip.'
                      : '${selectedItem!.title} is selected for activation.',
                  style: TextStyle(
                    color: AppColors.blackCat.withOpacity(0.72),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedItemTile extends StatelessWidget {
  const _SavedItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _SavedNfcItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            color: AppColors.snow,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: selected
                  ? AppColors.blackCat
                  : AppColors.blackCat.withOpacity(0.18),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: AppColors.blackCat, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.blackCat,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Arialbold',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.value,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.blackCat.withOpacity(0.70),
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: item.key,
                groupValue: selected ? item.key : null,
                activeColor: AppColors.blackCat,
                onChanged: (_) => onTap(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedScanItemCard extends StatelessWidget {
  const _SelectedScanItemCard({required this.item});

  final _SavedNfcItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: AppColors.blackCat, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected ${item.section}',
                  style: TextStyle(
                    color: AppColors.blackCat.withOpacity(0.62),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.blackCat,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Arialbold',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: TextStyle(
                    color: AppColors.blackCat.withOpacity(0.72),
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.isActivated});
  final bool isActivated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.snow,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: AppColors.blackCat.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.balletSlippers.withOpacity(0.45),
              borderRadius: BorderRadius.zero,
            ),
            child: const Icon(
              Icons.nfc_rounded,
              color: AppColors.blackCat,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppColors.blackCat,
                      fontFamily: 'Arialbold',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      const TextSpan(text: 'Status: '),
                      TextSpan(
                        text: isActivated ? 'Activated' : 'Not Activated',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Configure your profile and save to continue.',
                  style: TextStyle(
                    color: AppColors.blackCat.withOpacity(0.72),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.blackCat,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Arialbold',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _IconTextField extends StatelessWidget {
  const _IconTextField({
    required this.controller,
    required this.hint,
    this.icon,
    this.materialIcon,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final _BrandIcon? icon;
  final IconData? materialIcon;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: _BrandIconView(icon: icon, materialIcon: materialIcon),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 42,
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  color: AppColors.blackCat,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: AppColors.blackCat.withOpacity(0.40),
                    fontSize: 12.5,
                  ),
                  filled: true,
                  fillColor: AppColors.snow,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.blackCat.withOpacity(0.18),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: AppColors.blackCat,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BrandIcon {
  instagram,
  tiktok,
  snapchat,
  facebook,
  linkedin,
  youtube,
  pinterest,
  xTwitter,
  threads,
  cashApp,
  venmo,
  paypal,
  applePay,
  zelle,
  spotify,
  appleMusic,
  amazonMusic,
  soundCloud,
}

class _BrandIconView extends StatelessWidget {
  const _BrandIconView({this.icon, this.materialIcon});
  final _BrandIcon? icon;
  final IconData? materialIcon;

  @override
  Widget build(BuildContext context) {
    if (materialIcon != null) {
      return Icon(materialIcon, color: AppColors.blackCat, size: 22);
    }

    final spec = _spec(icon!);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: spec.background,
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        spec.label,
        style: TextStyle(
          color: spec.foreground,
          fontSize: spec.fontSize,
          fontWeight: FontWeight.w900,
          fontFamily: 'Arialbold',
        ),
      ),
    );
  }

  _IconSpec _spec(_BrandIcon icon) {
    switch (icon) {
      case _BrandIcon.instagram:
        return const _IconSpec('IG', Color(0xFFE4405F), Colors.white, 9);
      case _BrandIcon.tiktok:
        return const _IconSpec('♪', Colors.black, Colors.white, 18);
      case _BrandIcon.snapchat:
        return const _IconSpec('S', Color(0xFFFFFC00), Colors.black, 14);
      case _BrandIcon.facebook:
        return const _IconSpec('f', Color(0xFF1877F2), Colors.white, 20);
      case _BrandIcon.linkedin:
        return const _IconSpec('in', Color(0xFF0A66C2), Colors.white, 13);
      case _BrandIcon.youtube:
        return const _IconSpec('▶', Color(0xFFFF0000), Colors.white, 13);
      case _BrandIcon.pinterest:
        return const _IconSpec('P', Color(0xFFE60023), Colors.white, 15);
      case _BrandIcon.xTwitter:
        return const _IconSpec('X', Colors.white, Colors.black, 15);
      case _BrandIcon.threads:
        return const _IconSpec('@', Colors.white, Colors.black, 16);
      case _BrandIcon.cashApp:
        return const _IconSpec(r'$', Color(0xFF00D632), Colors.white, 18);
      case _BrandIcon.venmo:
        return const _IconSpec('V', Color(0xFF3D95CE), Colors.white, 15);
      case _BrandIcon.paypal:
        return const _IconSpec('P', Color(0xFF003087), Colors.white, 15);
      case _BrandIcon.applePay:
        return const _IconSpec('Pay', Colors.black, Colors.white, 9);
      case _BrandIcon.zelle:
        return const _IconSpec('Z', Color(0xFF6D1ED4), Colors.white, 15);
      case _BrandIcon.spotify:
        return const _IconSpec('♬', Color(0xFF1DB954), Colors.white, 17);
      case _BrandIcon.appleMusic:
        return const _IconSpec('♪', Color(0xFFFA2D48), Colors.white, 17);
      case _BrandIcon.amazonMusic:
        return const _IconSpec('am', Color(0xFF3216A8), Colors.white, 10);
      case _BrandIcon.soundCloud:
        return const _IconSpec('☁', Color(0xFFFF7700), Colors.white, 16);
    }
  }
}

class _IconSpec {
  const _IconSpec(this.label, this.background, this.foreground, this.fontSize);
  final String label;
  final Color background;
  final Color foreground;
  final double fontSize;
}
