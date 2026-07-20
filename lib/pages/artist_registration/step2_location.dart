import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../theme/app_colors.dart';
import '_widgets/reg_helpers.dart';
import 'registration_draft.dart';

class Step2Location extends StatefulWidget {
  const Step2Location({super.key, required this.draft});

  final RegistrationDraft draft;

  @override
  State<Step2Location> createState() => Step2LocationState();
}

class Step2LocationState extends State<Step2Location> {
  static const int _maxBytes = 2 * 1024 * 1024;
  static const int _maxEdge = 1600;
  static const Set<String> _allowedExts = {'.jpg', '.jpeg', '.png', '.webp'};

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _projectNotesCtrl;
  late final TextEditingController _instagramCtrl;
  late final TextEditingController _tiktokCtrl;
  late NailTechType _nailTechType;
  late final TextEditingController _licenseCtrl;
  String? _jurisdiction;
  String? _proYearsExp;
  late final TextEditingController _schoolCtrl;
  String? _practiceDuration;
  late List<Uint8List> _portfolioImages;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _projectNotesCtrl = TextEditingController(text: d.projectNotes);
    _instagramCtrl = TextEditingController(text: d.instagram);
    _tiktokCtrl = TextEditingController(text: d.tiktok);
    _nailTechType = d.nailTechType;
    _licenseCtrl = TextEditingController(text: d.licenseNumber);
    _jurisdiction = d.jurisdiction;
    _proYearsExp = d.proYearsExp;
    _schoolCtrl = TextEditingController(text: d.school);
    _practiceDuration = d.practiceDuration;
    _portfolioImages = List<Uint8List>.from(d.portfolioImages);
  }

  @override
  void dispose() {
    _projectNotesCtrl.dispose();
    _instagramCtrl.dispose();
    _tiktokCtrl.dispose();
    _licenseCtrl.dispose();
    _schoolCtrl.dispose();
    super.dispose();
  }

  void autofill() {
    setState(() {
      _nailTechType = NailTechType.professional;
      _licenseCtrl.text = 'NL-CA-2024-78901';
      _jurisdiction = 'California';
      _proYearsExp = '3–5 years (Skilled)';
      _instagramCtrl.text = '@luna_nails_art';
      _tiktokCtrl.text = '@lunanails';
      _projectNotesCtrl.text =
          'Available for custom seasonal collections and bridal sets.';
    });
  }

  bool validateAndSave(RegistrationDraft draft) {
    if (!(_formKey.currentState?.validate() ?? false)) return false;
    if (_instagramCtrl.text.trim().isEmpty && _tiktokCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter at least one Instagram or TikTok handle.',
          ),
        ),
      );
      return false;
    }

    draft.projectNotes = _projectNotesCtrl.text.trim();
    draft.instagram = _instagramCtrl.text.trim();
    draft.tiktok = _tiktokCtrl.text.trim();
    draft.nailTechType = _nailTechType;
    draft.licenseNumber = _licenseCtrl.text.trim();
    draft.jurisdiction = _jurisdiction;
    draft.proYearsExp = _proYearsExp;
    draft.school = _schoolCtrl.text.trim();
    draft.practiceDuration = _practiceDuration;
    draft.portfolioImages = List<Uint8List>.from(_portfolioImages);
    return true;
  }

  Future<void> _pickPortfolioImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 90);
    if (files.isEmpty) return;

    final added = <Uint8List>[];
    int rejectedSize = 0;
    int rejectedDecode = 0;
    int rejectedType = 0;

    for (final f in files) {
      final name = f.name.trim().isNotEmpty ? f.name : f.path;
      final dot = name.lastIndexOf('.');
      if (dot < 0 ||
          !_allowedExts.contains(name.substring(dot).toLowerCase())) {
        rejectedType++;
        continue;
      }
      final raw = await f.readAsBytes();
      final decoded = img.decodeImage(raw);
      if (decoded == null) {
        rejectedDecode++;
        continue;
      }

      img.Image processed = decoded;
      final maxSide = processed.width > processed.height
          ? processed.width
          : processed.height;
      if (maxSide > _maxEdge) {
        final scale = _maxEdge / maxSide;
        processed = img.copyResize(
          processed,
          width: (processed.width * scale).round(),
          height: (processed.height * scale).round(),
        );
      }
      final optimized = img.encodeJpg(processed, quality: 85);
      final bytes = Uint8List.fromList(optimized);
      if (bytes.lengthInBytes > _maxBytes) {
        rejectedSize++;
        continue;
      }
      added.add(bytes);
    }

    if (!mounted) return;
    if (added.isNotEmpty) {
      setState(() => _portfolioImages.addAll(added));
    }

    final msgs = <String>[];
    if (added.isNotEmpty) msgs.add('${added.length} added');
    if (rejectedType > 0) msgs.add('$rejectedType invalid format');
    if (rejectedSize > 0) msgs.add('$rejectedSize too large (max 2MB)');
    if (rejectedDecode > 0) msgs.add('$rejectedDecode unreadable');
    if (msgs.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Portfolio: ${msgs.join(', ')}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          regSectionCard(
            title: 'Portfolio',
            subtitle:
                'Upload previous art and share your professional credentials.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'I am:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _typeToggleOption(
                      NailTechType.professional,
                      'Professional Nail Technician',
                    ),
                    const SizedBox(width: 12),
                    _typeToggleOption(
                      NailTechType.student,
                      'Student / Unlicensed',
                    ),
                  ],
                ),
                const SizedBox(height: kFieldGap),
                if (_nailTechType == NailTechType.professional) ...[
                  TextFormField(
                    controller: _licenseCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec('License # *', 'Enter license number'),
                    validator: (v) =>
                        (_nailTechType == NailTechType.professional &&
                            (v == null || v.trim().isEmpty))
                        ? 'License # is required'
                        : null,
                  ),
                  const SizedBox(height: kFieldGap),
                  RegTypeAheadField(
                    label: 'Jurisdiction *',
                    hint: 'Select state',
                    options: kUsStates,
                    selectedValue: _jurisdiction,
                    onChanged: (v) => setState(() => _jurisdiction = v),
                    validator: (v) =>
                        (_nailTechType == NailTechType.professional &&
                            (v == null || v.isEmpty))
                        ? 'Jurisdiction is required'
                        : null,
                  ),
                  const SizedBox(height: kFieldGap),
                  RegPopupDropdown<String>(
                    label: 'Years of Experience *',
                    hint: 'Select years of experience',
                    value: _proYearsExp,
                    items: kProYearsOptions,
                    itemLabel: (s) => s,
                    onChanged: (v) => setState(() => _proYearsExp = v),
                    validator: (v) =>
                        (_nailTechType == NailTechType.professional &&
                            (v == null || v.isEmpty))
                        ? 'Years of experience is required'
                        : null,
                  ),
                ] else ...[
                  TextFormField(
                    controller: _schoolCtrl,
                    style: const TextStyle(fontSize: kInputFs),
                    decoration: regDec(
                      'School / Training Program *',
                      'Enter school or program name',
                    ),
                    validator: (v) =>
                        (_nailTechType == NailTechType.student &&
                            (v == null || v.trim().isEmpty))
                        ? 'School/Program is required'
                        : null,
                  ),
                  const SizedBox(height: kFieldGap),
                  RegPopupDropdown<String>(
                    label: 'How long have you been practicing? *',
                    hint: 'Select duration',
                    value: _practiceDuration,
                    items: kPracticeDurations,
                    itemLabel: (s) => s,
                    onChanged: (v) => setState(() => _practiceDuration = v),
                    validator: (v) =>
                        (_nailTechType == NailTechType.student &&
                            (v == null || v.isEmpty))
                        ? 'Duration is required'
                        : null,
                  ),
                ],
                const SizedBox(height: kFieldGap),
                Text(
                  'Upload previous Art',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blackCat.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Allowed: JPG, JPEG, PNG, WEBP. Each file must be <2MB.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.blackCat.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
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
                    Semantics(
                      button: true,
                      label: 'Add portfolio image',
                      onTap: _pickPortfolioImages,
                      child: ExcludeSemantics(
                        child: InkWell(
                      onTap: _pickPortfolioImages,
                      borderRadius: BorderRadius.zero,
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: AppColors.snow,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: AppColors.blackCat.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: AppColors.blackCat.withValues(alpha: 0.9),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                      border: Border.all(
                        color: AppColors.blackCat.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          color: AppColors.blackCat.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No previous art uploaded yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: kFieldGap),
                TextField(
                  controller: _projectNotesCtrl,
                  decoration: regDec('Project Notes', 'Project notes'),
                  style: const TextStyle(fontSize: kInputFs),
                ),
                const SizedBox(height: kFieldGap),
                TextField(
                  controller: _instagramCtrl,
                  decoration: regDec(
                    'Instagram (one required)',
                    'Instagram handle',
                  ),
                  style: const TextStyle(fontSize: kInputFs),
                ),
                const SizedBox(height: kFieldGap),
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

  Widget _typeToggleOption(NailTechType type, String label) {
    final selected = _nailTechType == type;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
        onTap: () => setState(() => _nailTechType = type),
        borderRadius: BorderRadius.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.blackCat.withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: selected
                  ? AppColors.blackCat
                  : AppColors.blackCat.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              if (selected)
                const Icon(Icons.check, size: 14, color: AppColors.blackCat),
              if (selected) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.blackCat
                        : AppColors.blackCat.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
