import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../../theme/app_colors.dart';
import '../../widgets/direct_request_year_calendar.dart';
import 'registration_draft.dart';
import '_widgets/reg_helpers.dart';

class Step3Specialization extends StatefulWidget {
  const Step3Specialization({super.key, required this.draft});

  final RegistrationDraft draft;

  @override
  State<Step3Specialization> createState() => Step3SpecializationState();
}

class Step3SpecializationState extends State<Step3Specialization> {
  static const int _maxBytes = 2 * 1024 * 1024;
  static const int _maxEdge = 1600;
  static const Set<String> _allowedExts = {'.jpg', '.jpeg', '.png', '.webp'};

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _minPriceCtrl;
  late final TextEditingController _maxPriceCtrl;
  late final TextEditingController _projectNotesCtrl;
  late final TextEditingController _instagramCtrl;
  late final TextEditingController _tiktokCtrl;

  late Set<String> _services;
  late bool _rush;
  late bool _directRequestsEnabled;
  late int _directRequestYear;
  late Set<DateTime> _blockedDates;
  late List<Uint8List> _portfolioImages;

  bool _showCalendar = false;
  int _calendarNonce = 0;

  static const List<String> _serviceOptions = [
    'Intricate Nail Art', 'Gel / Acrylic', '3D Nail Art', 'Airbrush/Stamping',
    'Encapsulation', 'Dip Powder', 'Sculptured', 'PolyGel', 'Chrome & Metallic',
    'Custom Press-ons', 'Nail Art',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _minPriceCtrl = TextEditingController(text: d.minPrice);
    _maxPriceCtrl = TextEditingController(text: d.maxPrice);
    _projectNotesCtrl = TextEditingController(text: d.projectNotes);
    _instagramCtrl = TextEditingController(text: d.instagram);
    _tiktokCtrl = TextEditingController(text: d.tiktok);
    _services = Set.from(d.services);
    _rush = d.rush;
    _directRequestsEnabled = d.directRequestsEnabled;
    _directRequestYear = d.directRequestYear;
    _blockedDates = Set.from(d.blockedDates);
    _portfolioImages = List.from(d.portfolioImages);
  }

  @override
  void dispose() {
    _minPriceCtrl.dispose();
    _maxPriceCtrl.dispose();
    _projectNotesCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    super.dispose();
  }

  void autofill() {
    setState(() {
      _services
        ..clear()
        ..addAll({'Intricate Nail Art', 'Gel / Acrylic', 'Chrome & Metallic', '3D Nail Art'});
      _minPriceCtrl.text = '50';
      _maxPriceCtrl.text = '350';
      _rush = true;
      _directRequestsEnabled = true;
      _instagramCtrl.text = '@luna_nails_art';
      _tiktokCtrl.text = '@lunanails';
      _projectNotesCtrl.text = 'Available for custom seasonal collections and bridal sets.';
    });
  }

  bool validateAndSave(RegistrationDraft draft) {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_instagramCtrl.text.trim().isEmpty && _tiktokCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one Instagram or TikTok handle.')),
      );
      return false;
    }
    draft.services = Set.from(_services);
    draft.minPrice = _minPriceCtrl.text.trim();
    draft.maxPrice = _maxPriceCtrl.text.trim();
    draft.rush = _rush;
    draft.directRequestsEnabled = _directRequestsEnabled;
    draft.directRequestYear = _directRequestYear;
    draft.blockedDates = Set.from(_blockedDates);
    draft.portfolioImages = List.from(_portfolioImages);
    draft.projectNotes = _projectNotesCtrl.text.trim();
    draft.instagram = _instagramCtrl.text.trim();
    draft.tiktok = _tiktokCtrl.text.trim();
    return true;
  }

  Future<void> _pickPortfolioImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 90);
    if (files.isEmpty) return;

    final added = <Uint8List>[];
    int rejectedSize = 0, rejectedDecode = 0, rejectedType = 0;

    for (final f in files) {
      final name = f.name.trim().isNotEmpty ? f.name : f.path;
      final dot = name.lastIndexOf('.');
      if (dot < 0 || !_allowedExts.contains(name.substring(dot).toLowerCase())) {
        rejectedType++;
        continue;
      }
      final raw = await f.readAsBytes();
      final decoded = img.decodeImage(raw);
      if (decoded == null) { rejectedDecode++; continue; }

      img.Image processed = decoded;
      final maxSide = processed.width > processed.height ? processed.width : processed.height;
      if (maxSide > _maxEdge) {
        final scale = _maxEdge / maxSide;
        processed = img.copyResize(processed, width: (processed.width * scale).round(), height: (processed.height * scale).round());
      }
      final optimized = img.encodeJpg(processed, quality: 85);
      final bytes = Uint8List.fromList(optimized);
      if (bytes.lengthInBytes > _maxBytes) { rejectedSize++; continue; }
      added.add(bytes);
    }

    if (!mounted) return;
    if (added.isNotEmpty) setState(() => _portfolioImages.addAll(added));

    final msgs = <String>[];
    if (added.isNotEmpty) msgs.add('${added.length} added');
    if (rejectedType > 0) msgs.add('$rejectedType invalid format');
    if (rejectedSize > 0) msgs.add('$rejectedSize too large (max 2MB)');
    if (rejectedDecode > 0) msgs.add('$rejectedDecode unreadable');
    if (msgs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Portfolio: ${msgs.join(', ')}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          // ── Specialization & Pricing ───────────────────────────────────────
          regSectionCard(
            title: 'Specialization & Pricing',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _serviceOptions.map((s) {
                    return regChip(s, _services.contains(s), () {
                      setState(() => _services.contains(s) ? _services.remove(s) : _services.add(s));
                    });
                  }).toList(),
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minPriceCtrl,
                        style: const TextStyle(fontSize: kInputFs),
                        keyboardType: TextInputType.number,
                        decoration: regDec('Min Price (\$) *', '50'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _maxPriceCtrl,
                        style: const TextStyle(fontSize: kInputFs),
                        keyboardType: TextInputType.number,
                        decoration: regDec('Max Price (\$) *', '200'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rush availability', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.blackCat)),
                          const SizedBox(height: 4),
                          Text('Enable if you can take expedited requests.', style: TextStyle(fontSize: 13, color: AppColors.blackCat.withValues(alpha: 0.65), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 0.88,
                      child: Switch(
                        value: _rush,
                        onChanged: (v) => setState(() => _rush = v),
                        activeThumbColor: const Color(0xFF1F1B24),
                        activeTrackColor: const Color(0xFF1F1B24).withValues(alpha: 0.45),
                        inactiveThumbColor: AppColors.blackCatLight,
                        inactiveTrackColor: AppColors.blackCatLight.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Year Calendar Availability ─────────────────────────────────────
          regSectionCard(
            title: 'Year Calendar Availability',
            subtitle: 'Control when your Direct Request button is available. Block off specific days, weeks, or months. Optional.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Direct Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'ArialBold', color: AppColors.blackCat)),
                    const Spacer(),
                    Transform.scale(
                      scale: 0.88,
                      child: Switch(
                        value: _directRequestsEnabled,
                        onChanged: (v) => setState(() => _directRequestsEnabled = v),
                        activeThumbColor: const Color(0xFF1F1B24),
                        activeTrackColor: const Color(0xFF1F1B24).withValues(alpha: 0.45),
                        inactiveThumbColor: AppColors.blackCatLight,
                        inactiveTrackColor: AppColors.blackCatLight.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
                Text(
                  _directRequestsEnabled
                      ? 'Clients can send Direct Requests on unblocked dates.'
                      : 'Direct Requests are currently turned OFF.',
                  style: TextStyle(color: AppColors.blackCat.withValues(alpha: 0.65), fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(_showCalendar ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => setState(() {
                      _showCalendar = !_showCalendar;
                      if (_showCalendar) _calendarNonce = DateTime.now().millisecondsSinceEpoch;
                    }),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.snow,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DirectRequestYearCalendar(
                          key: ValueKey(_calendarNonce),
                          initialDirectRequestsOn: _directRequestsEnabled,
                          initialYear: _directRequestYear,
                          initialMonth: DateTime.now().month,
                          initialBlockedDays: _blockedDates,
                          showDirectRequestsFooter: false,
                          onChanged: (directOn, year, blocked) {
                            setState(() {
                              _directRequestsEnabled = directOn;
                              _directRequestYear = year;
                              _blockedDates..clear()..addAll(blocked);
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tip: Tap a day to block it. Tap the week strip to block a week. Tap the month title to block the whole month.',
                                style: TextStyle(color: AppColors.blackCat.withValues(alpha: 0.6), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: _showCalendar ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Portfolio ──────────────────────────────────────────────────────
          regSectionCard(
            title: 'Portfolio',
            subtitle: 'Upload Previous Art. (${_portfolioImages.length} photo(s))',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Upload previous Art',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.blackCat.withValues(alpha: 0.8)),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Allowed: JPG, JPEG, PNG, WEBP. Each file must be <2MB.',
                  style: TextStyle(fontSize: 13, color: AppColors.blackCat.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ..._portfolioImages.map((b) {
                      return ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: Container(
                          width: 86,
                          height: 86,
                          color: AppColors.snow,
                          child: Image.memory(b, fit: BoxFit.cover),
                        ),
                      );
                    }),
                    InkWell(
                      onTap: _pickPortfolioImages,
                      borderRadius: BorderRadius.zero,
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: AppColors.snow,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: AppColors.blackCat.withValues(alpha: 0.9)),
                            const SizedBox(height: 6),
                            const Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                if (_portfolioImages.isEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.snow,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: AppColors.blackCat.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.image_outlined, color: AppColors.blackCat.withValues(alpha: 0.55)),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('No previous art uploaded yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                TextField(
                  controller: _projectNotesCtrl,
                  decoration: regDec('Project Notes', 'Project notes'),
                  style: const TextStyle(fontSize: kInputFs),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _instagramCtrl,
                  decoration: regDec('Instagram (one required)', 'Instagram handle'),
                  style: const TextStyle(fontSize: kInputFs),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _tiktokCtrl,
                  decoration: regDec('TikTok', 'TikTok handle'),
                  style: const TextStyle(fontSize: kInputFs),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
