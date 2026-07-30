// lib/pages/nfc_smart_nail_profile_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';

SupabaseClient get _supabase => Supabase.instance.client;

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

class _NfcProfileTarget {
  const _NfcProfileTarget({
    required this.table,
    required this.uid,
    required this.data,
  });

  final String table;
  final String uid;
  final Map<String, dynamic> data;

  Map<String, dynamic> get profile =>
      _asMap(data['nfc_smart_nail_profile'] ?? data['nfcSmartNailProfile']);
}

Future<_NfcProfileTarget?> _findNfcProfileTarget(String uid) async {
  for (final table in const <String>['client', 'client_artist']) {
    final row = await _supabase
        .from(table)
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (row != null) {
      return _NfcProfileTarget(
        table: table,
        uid: uid,
        data: Map<String, dynamic>.from(row),
      );
    }
  }
  return null;
}

Future<void> _saveNfcProfileForUser({
  required String uid,
  required Map<String, dynamic> profile,
}) async {
  final target = await _findNfcProfileTarget(uid);
  final resolvedTarget =
      target ??
      _NfcProfileTarget(table: 'client_artist', uid: uid, data: const {});
  final mergedClient = <String, dynamic>{
    ..._asMap(resolvedTarget.data['client']),
    'nfcSmartNailProfile': profile,
  };
  final nowIso = DateTime.now().toIso8601String();
  await _supabase.from(resolvedTarget.table).upsert({
    'id': uid,
    'nfc_smart_nail_profile': profile,
    'client': mergedClient,
    'updated_at': nowIso,
  }, onConflict: 'id');
}

// Public resolver domain written to every chip's NDEF record. Keep this as
// the single place the domain is referenced -- see supabase/functions/
// nfc-resolve/index.ts for the server-side lookup this URL hits at tap time.
const String kNfcResolverBaseUrl = 'https://www.jntnails.com/n/';

/// A single physical NFC chip an owner has activated. An owner can have
/// several of these at once (e.g. one per finger), each independently
/// switchable without ever needing to rewrite the physical chip -- only
/// `activeItemKey`/`activeItemType`/`activeItemValue` change on "Change",
/// and only `status` changes on "Report lost/damaged".
class NfcChip {
  const NfcChip({
    required this.id,
    required this.ownerId,
    required this.ownerTable,
    required this.label,
    required this.status,
    required this.activeItemKey,
    required this.activeItemType,
    required this.activeItemValue,
  });

  final String id;
  final String ownerId;
  final String ownerTable;
  final String? label;
  final String status;
  final String? activeItemKey;
  final String? activeItemType;
  final String? activeItemValue;

  bool get isActive => status == 'active';

  String get resolverUrl => '$kNfcResolverBaseUrl$id';

  factory NfcChip.fromRow(Map<String, dynamic> row) {
    String? text(dynamic v) => v == null ? null : v.toString();
    return NfcChip(
      id: (row['id'] ?? '').toString(),
      ownerId: (row['owner_id'] ?? '').toString(),
      ownerTable: (row['owner_table'] ?? '').toString(),
      label: text(row['label']),
      status: (row['status'] ?? 'active').toString(),
      activeItemKey: text(row['active_item_key']),
      activeItemType: text(row['active_item_type']),
      activeItemValue: text(row['active_item_value']),
    );
  }
}

Future<List<NfcChip>> _fetchChips(String uid) async {
  final rows = await _supabase
      .from('nfc_chips')
      .select()
      .eq('owner_id', uid)
      .order('created_at', ascending: false);
  return (rows as List)
      .map((row) => NfcChip.fromRow(Map<String, dynamic>.from(row as Map)))
      .toList();
}

Future<NfcChip> _createChipRow({
  required String uid,
  required String ownerTable,
  required String itemKey,
  required String itemType,
  required String itemValue,
  String? label,
}) async {
  final nowIso = DateTime.now().toIso8601String();
  final row = await _supabase
      .from('nfc_chips')
      .insert({
        'owner_id': uid,
        'owner_table': ownerTable,
        'label': label,
        'status': 'active',
        'active_item_key': itemKey,
        'active_item_type': itemType,
        'active_item_value': itemValue,
        'activated_at': nowIso,
      })
      .select()
      .single();
  return NfcChip.fromRow(Map<String, dynamic>.from(row));
}

Future<void> _deleteChipRow(String chipId) async {
  await _supabase.from('nfc_chips').delete().eq('id', chipId);
}

Future<void> _updateChipActiveItem({
  required String chipId,
  required String itemKey,
  required String itemType,
  required String itemValue,
}) async {
  await _supabase
      .from('nfc_chips')
      .update({
        'active_item_key': itemKey,
        'active_item_type': itemType,
        'active_item_value': itemValue,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', chipId);
}

Future<void> _deactivateChip({
  required String chipId,
  required String reason,
}) async {
  final nowIso = DateTime.now().toIso8601String();
  await _supabase
      .from('nfc_chips')
      .update({
        'status': reason == 'damaged'
            ? 'deactivated_damaged'
            : 'deactivated_lost',
        'deactivated_at': nowIso,
        'deactivated_reason': reason,
        'deactivated_by': 'self',
        'updated_at': nowIso,
      })
      .eq('id', chipId);
}

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
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final target = await _findNfcProfileTarget(uid);
      final data = target?.profile;
      if (!mounted || data == null) return;

      for (final entry in _controllers.entries) {
        entry.value.text = (data[entry.key] ?? '').toString();
      }
    } catch (e) {
      debugPrint(
        'NfcSmartNailProfilePage: failed to load existing profile: $e',
      );
    }
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final uid = _supabase.auth.currentUser?.id;
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
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _saveNfcProfileForUser(uid: uid, profile: payload);

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
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'NFC nail profile',
      child: Scaffold(
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
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.blackCat,
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            children: [
              _StatusCard(isActivated: false),
              const SizedBox(height: 20),
              _SectionTitle('Social Links'),
              _IconTextField(
                controller: _controllers['instagram']!,
                hint: 'Instagram username or link',
              ),
              _IconTextField(
                controller: _controllers['tiktok']!,
                hint: 'TikTok username or link',
              ),
              _IconTextField(
                controller: _controllers['snapchat']!,
                hint: 'Snapchat username or link',
              ),
              _IconTextField(
                controller: _controllers['facebook']!,
                hint: 'Facebook username or link',
              ),
              _IconTextField(
                controller: _controllers['linkedin']!,
                hint: 'LinkedIn username or link',
              ),
              _IconTextField(
                controller: _controllers['youtube']!,
                hint: 'YouTube username or link',
              ),
              _IconTextField(
                controller: _controllers['pinterest']!,
                hint: 'Pinterest username or link',
              ),
              _IconTextField(
                controller: _controllers['xTwitter']!,
                hint: 'X username or link',
              ),
              _IconTextField(
                controller: _controllers['threads']!,
                hint: 'Threads username or link',
              ),

              const SizedBox(height: 16),
              _SectionTitle('Contact Information'),
              _IconTextField(
                controller: _controllers['contactName']!,
                hint: 'Name',
              ),
              _IconTextField(
                controller: _controllers['contactPhone']!,
                hint: 'Phone',
                keyboardType: TextInputType.phone,
              ),
              _IconTextField(
                controller: _controllers['contactEmail']!,
                hint: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              _IconTextField(
                controller: _controllers['contactWebsite']!,
                hint: 'Website',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              _IconTextField(
                controller: _controllers['emergencyContactName']!,
                hint: 'Emergency contact name',
              ),
              _IconTextField(
                controller: _controllers['emergencyContactPhone']!,
                hint: 'Emergency contact phone',
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 16),
              _SectionTitle('Website'),
              _IconTextField(
                controller: _controllers['website']!,
                hint: 'Website URL',
                keyboardType: TextInputType.url,
              ),
              _IconTextField(
                controller: _controllers['website2']!,
                hint: 'Website URL 2',
                keyboardType: TextInputType.url,
              ),
              _IconTextField(
                controller: _controllers['website3']!,
                hint: 'Website URL 3',
                keyboardType: TextInputType.url,
              ),

              const SizedBox(height: 16),
              _SectionTitle('Payment Links'),
              _IconTextField(
                controller: _controllers['cashApp']!,
                hint: 'CashApp cashtag',
              ),
              _IconTextField(
                controller: _controllers['venmo']!,
                hint: 'Venmo username',
              ),
              _IconTextField(
                controller: _controllers['paypal']!,
                hint: 'PayPal link or email',
              ),
              _IconTextField(
                controller: _controllers['applePay']!,
                hint: 'Apple Pay phone or email',
              ),
              _IconTextField(
                controller: _controllers['zelle']!,
                hint: 'Zelle phone or email',
              ),

              const SizedBox(height: 16),
              _SectionTitle('Music'),
              _IconTextField(
                controller: _controllers['spotify']!,
                hint: 'Spotify playlist or artist link',
              ),
              _IconTextField(
                controller: _controllers['appleMusic']!,
                hint: 'Apple Music link',
              ),
              _IconTextField(
                controller: _controllers['amazonMusic']!,
                hint: 'Amazon Music link',
              ),
              _IconTextField(
                controller: _controllers['soundCloud']!,
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
                    disabledBackgroundColor: AppColors.blackCat.withValues(
                      alpha: 0.55,
                    ),
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
                  color: AppColors.blackCat.withValues(alpha: 0.65),
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
  List<NfcChip> _chips = const [];
  bool _loadingChips = true;

  @override
  void initState() {
    super.initState();
    _loadChips();
  }

  Future<void> _loadChips() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loadingChips = false);
      return;
    }
    try {
      final chips = await _fetchChips(uid);
      if (!mounted) return;
      setState(() {
        _chips = chips;
        _loadingChips = false;
      });
    } catch (e) {
      debugPrint('NfcSavedItemsPage: failed to load chips: $e');
      if (!mounted) return;
      setState(() => _loadingChips = false);
    }
  }

  _SavedNfcItem? _findSavedItem(String key) {
    for (final section in _sections) {
      for (final item in section.items) {
        if (item.key == key) return item;
      }
    }
    return null;
  }

  Future<void> _changeActiveItem(NfcChip chip) async {
    final picked = await showModalBottomSheet<_SavedNfcItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.snow,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                'Choose what this chip shares',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 12),
              for (final section in _sections) ...[
                _SectionTitle(section.title),
                ...section.items.map(
                  (item) => _SavedItemTile(
                    item: item,
                    selected: chip.activeItemKey == item.key,
                    onTap: () => Navigator.pop(sheetContext, item),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    try {
      await _updateChipActiveItem(
        chipId: chip.id,
        itemKey: picked.key,
        itemType: picked.title,
        itemValue: picked.value,
      );
      await _loadChips();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${picked.title} is now active on this chip.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update chip: $e')));
    }
  }

  Future<void> _reportLostOrDamaged(NfcChip chip) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report this chip'),
          content: const Text(
            'This will deactivate the chip so it no longer shares your information. '
            'You can activate a new chip afterward.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'lost'),
              child: const Text('Lost'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'damaged'),
              child: const Text('Damaged'),
            ),
          ],
        );
      },
    );
    if (reason == null || !mounted) return;
    try {
      await _deactivateChip(chipId: chip.id, reason: reason);
      await _loadChips();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chip deactivated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to deactivate chip: $e')));
    }
  }

  Widget _myChipsSection() {
    if (_loadingChips) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('My Chips'),
          for (final chip in _chips)
            _MyChipTile(
              chip: chip,
              activeItemTitle: chip.activeItemKey == null
                  ? null
                  : (_findSavedItem(chip.activeItemKey!)?.title ??
                        chip.activeItemType),
              onChange: chip.isActive ? () => _changeActiveItem(chip) : null,
              onReport: chip.isActive ? () => _reportLostOrDamaged(chip) : null,
            ),
        ],
      ),
    );
  }

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

  Future<void> _activateSelectedItem() async {
    final selected = _selectedItem;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select one saved item to activate.'),
        ),
      );
      return;
    }

    final activated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NfcScanActivationPage(
          selectedItem: selected,
          chipLabel: _chips.isEmpty ? null : 'Chip ${_chips.length + 1}',
        ),
      ),
    );
    if (activated == true) {
      await _loadChips();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'NFC saved items',
      child: Scaffold(
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
            tooltip: 'Back',
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
                        _myChipsSection(),
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
                                : (_chips.isEmpty
                                      ? 'Activate NFC Nail'
                                      : 'Activate Another Chip'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blackCat,
                            foregroundColor: AppColors.snow,
                            disabledBackgroundColor: AppColors.blackCat
                                .withValues(alpha: 0.55),
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
      ),
    );
  }
}

class NfcScanActivationPage extends StatefulWidget {
  const NfcScanActivationPage({
    super.key,
    required this.selectedItem,
    this.chipLabel,
  });

  final _SavedNfcItem selectedItem;
  final String? chipLabel;

  @override
  State<NfcScanActivationPage> createState() => _NfcScanActivationPageState();
}

class _NfcScanActivationPageState extends State<NfcScanActivationPage> {
  bool _isScanning = false;
  bool _isActivated = false;
  String? _statusMessage;

  Future<void> _startNfcScanAndActivate() async {
    if (_isScanning || _isActivated) return;

    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Missing signed-in user.')));
      return;
    }

    final isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NFC is not available on this device.')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _statusMessage = 'Hold your NFC nail near your phone.';
    });

    // Create the chip row up front so its id can be embedded in the stable
    // resolver URL written to the physical chip. Rolled back (deleted) below
    // if the physical write itself fails, so a failed activation never
    // leaves behind a phantom "active" chip.
    final NfcChip createdChip;
    try {
      final target = await _findNfcProfileTarget(uid);
      createdChip = await _createChipRow(
        uid: uid,
        ownerTable: target?.table ?? 'client_artist',
        itemKey: widget.selectedItem.key,
        itemType: widget.selectedItem.title,
        itemValue: widget.selectedItem.value,
        label: widget.chipLabel,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _statusMessage = 'Failed to prepare chip: $e';
      });
      return;
    }

    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      alertMessage: 'Hold your NFC nail near the top of your phone.',
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            await NfcManager.instance.stopSession(
              errorMessage: 'This NFC tag does not support NDEF.',
            );
            await _deleteChipRow(createdChip.id);
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
            await _deleteChipRow(createdChip.id);
            if (mounted) {
              setState(() {
                _isScanning = false;
                _statusMessage = 'This NFC tag is not writable.';
              });
            }
            return;
          }

          // Write the stable resolver URL, not the destination itself --
          // changing what's active later is a DB update, never a re-tap.
          final message = NdefMessage([
            NdefRecord.createUri(Uri.parse(createdChip.resolverUrl)),
          ]);

          await ndef.write(message);

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
              content: Text(
                '${widget.selectedItem.title} activated successfully.',
              ),
            ),
          );
        } catch (e) {
          await NfcManager.instance.stopSession(
            errorMessage: 'Failed to activate NFC nail.',
          );
          try {
            await _deleteChipRow(createdChip.id);
          } catch (_) {}
          if (!mounted) return;
          setState(() {
            _isScanning = false;
            _statusMessage = 'Failed to activate NFC nail: $e';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusText =
        _statusMessage ??
        (_isScanning
            ? 'Keep your NFC nail near your phone.'
            : 'Hold your NFC nail near the top of your phone to activate it.');

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: 'NFC scan activation',
      child: Scaffold(
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
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.blackCat,
            onPressed: () async {
              if (_isScanning) {
                await NfcManager.instance.stopSession(
                  errorMessage: 'Cancelled',
                );
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
                  border: Border.all(
                    color: AppColors.blackCat.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _isActivated ? Icons.check_rounded : Icons.nfc_rounded,
                      color: AppColors.blackCat,
                      size: 36,
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
                        color: AppColors.blackCat.withValues(alpha: 0.70),
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
                  onPressed: _isActivated
                      ? () => Navigator.pop(context, true)
                      : _startNfcScanAndActivate,
                  icon: _isScanning
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.snow,
                          ),
                        )
                      : Icon(
                          _isActivated
                              ? Icons.done_rounded
                              : Icons.sensors_rounded,
                          size: 20,
                        ),
                  label: Text(
                    _isActivated
                        ? 'Done'
                        : (_isScanning ? 'Scanning...' : 'Start NFC Scan'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blackCat,
                    foregroundColor: AppColors.snow,
                    disabledBackgroundColor: AppColors.blackCat.withValues(
                      alpha: 0.55,
                    ),
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
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.balletSlippers.withValues(alpha: 0.45),
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
                    color: AppColors.blackCat.withValues(alpha: 0.72),
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

class _MyChipTile extends StatelessWidget {
  const _MyChipTile({
    required this.chip,
    required this.activeItemTitle,
    required this.onChange,
    required this.onReport,
  });

  final NfcChip chip;
  final String? activeItemTitle;
  final VoidCallback? onChange;
  final VoidCallback? onReport;

  String get _statusLabel {
    switch (chip.status) {
      case 'deactivated_lost':
        return 'Lost';
      case 'deactivated_damaged':
        return 'Damaged';
      case 'replaced':
        return 'Replaced';
      default:
        return 'Active';
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = chip.label?.trim().isNotEmpty == true
        ? chip.label!.trim()
        : 'NFC Chip';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.snow,
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chip.isActive
                      ? AppColors.balletSlippers.withValues(alpha: 0.6)
                      : AppColors.blackCat.withValues(alpha: 0.10),
                ),
                child: Text(
                  _statusLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            activeItemTitle == null
                ? 'Nothing shared yet'
                : 'Sharing: $activeItemTitle',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.blackCat.withValues(alpha: 0.70),
            ),
          ),
          if (onChange != null || onReport != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onChange != null)
                  TextButton(onPressed: onChange, child: const Text('Change')),
                if (onReport != null)
                  TextButton(
                    onPressed: onReport,
                    child: const Text('Report Lost/Damaged'),
                  ),
              ],
            ),
          ],
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
      child: Semantics(
        button: true,
        selected: selected,
        label: item.title,
        child: ExcludeSemantics(
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
                      : AppColors.blackCat.withValues(alpha: 0.18),
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
                            color: AppColors.blackCat.withValues(alpha: 0.70),
                            fontSize: 12.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RadioGroup<String>(
                    groupValue: selected ? item.key : null,
                    onChanged: (_) => onTap(),
                    child: Radio<String>(
                      value: item.key,
                      activeColor: AppColors.blackCat,
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
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.18)),
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
                    color: AppColors.blackCat.withValues(alpha: 0.62),
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
                    color: AppColors.blackCat.withValues(alpha: 0.72),
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
        border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.balletSlippers.withValues(alpha: 0.45),
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
                    color: AppColors.blackCat.withValues(alpha: 0.72),
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
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                    color: AppColors.blackCat.withValues(alpha: 0.40),
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
                      color: AppColors.blackCat.withValues(alpha: 0.18),
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

